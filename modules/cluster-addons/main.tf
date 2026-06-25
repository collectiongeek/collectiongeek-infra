# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# NGINX Ingress Controller (F5 NGINX, OSS edition)
# =============================================================================
# Migrated off the community kubernetes/ingress-nginx chart, which the upstream
# Kubernetes project retired in March 2026 (no further security patches). This
# is F5's actively-maintained nginxinc/kubernetes-ingress controller.
#
# Cutover note: the release `name` changed (ingress-nginx -> nginx-ingress),
# which forces Terraform to destroy the old release before creating this one.
# That cleanly removes the community controller, its `nginx` IngressClass, and
# its NLB, then provisions the F5 controller fresh (new NLB; external-dns
# re-points Route 53 automatically). The IngressClass keeps the name "nginx" so
# existing Ingress objects (apps + Argo CD) need no className change.
resource "helm_release" "ingress_nginx" {
  name             = "nginx-ingress"
  namespace        = "ingress-nginx"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-ingress"
  version          = "2.6.0"
  create_namespace = true

  set = [
    # OSS edition (not NGINX Plus)
    {
      name  = "nginxplus"
      value = "false"
    },
    # Keep the IngressClass named "nginx" so existing Ingresses are unaffected
    {
      name  = "controller.ingressClass.name"
      value = "nginx"
    },
    {
      name  = "controller.ingressClass.create"
      value = "true"
    },
    # Use NLB (Network Load Balancer) instead of CLB.
    # type = "string" stops Terraform coercing values like "true" into booleans;
    # the F5 chart's schema requires annotation values to be strings.
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
      type  = "string"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
      value = "internet-facing"
      type  = "string"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
      value = "true"
      type  = "string"
    },
    # Resource requests for Karpenter scheduling
    {
      name  = "controller.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "controller.resources.requests.memory"
      value = "128Mi"
    },
    # Tolerate system node taint so it can run on system nodes too
    {
      name  = "controller.tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "controller.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "controller.tolerations[0].effect"
      value = "NoSchedule"
    },
    # Replica count
    {
      name  = "controller.replicaCount"
      value = var.environment == "prod" ? "2" : "1"
    },
  ]
}

# =============================================================================
# cert-manager
# =============================================================================

# IRSA role for cert-manager in this account
# This role assumes the cross-account role in SharedServices
resource "aws_iam_role" "cert_manager" {
  name = "${var.cluster_name}-cert-manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
            "${var.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:cert-manager:cert-manager"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cert_manager" {
  name = "cert-manager-assume-dns-role"
  role = aws_iam_role.cert_manager.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.cert_manager_role_arn
      }
    ]
  })
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "1.17.1"
  create_namespace = true

  set = [
    # Install CRDs
    {
      name  = "crds.enabled"
      value = "true"
    },
    # IRSA annotation
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.cert_manager.arn
    },
    # Resource requests
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    },
    # Tolerate system node taint
    {
      name  = "tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    },
  ]
}

# ClusterIssuer for Let's Encrypt (production)
resource "kubectl_manifest" "cluster_issuer_prod" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "admin@${var.domain_name}"
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region       = data.aws_region.current.name
                hostedZoneID = var.route53_zone_id
                role         = var.cert_manager_role_arn
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

# ClusterIssuer for Let's Encrypt (staging — for testing, no rate limits)
resource "kubectl_manifest" "cluster_issuer_staging" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = "admin@${var.domain_name}"
        privateKeySecretRef = {
          name = "letsencrypt-staging-key"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region       = data.aws_region.current.name
                hostedZoneID = var.route53_zone_id
                role         = var.cert_manager_role_arn
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

# =============================================================================
# external-dns
# =============================================================================

# IRSA role for external-dns in this account
resource "aws_iam_role" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
            "${var.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:external-dns:external-dns"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_dns" {
  name = "external-dns-assume-dns-role"
  role = aws_iam_role.external_dns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.dns_manager_role_arn
      }
    ]
  })
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  namespace        = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  version          = "1.15.1"
  create_namespace = true

  set = [
    # AWS provider configuration
    {
      name  = "provider.name"
      value = "aws"
    },
    # Use the cross-account role for Route 53 access
    {
      name  = "extraArgs[0]"
      value = "--aws-assume-role=${var.dns_manager_role_arn}"
    },
    # Only manage records for our domain
    {
      name  = "domainFilters[0]"
      value = var.domain_name
    },
    # TXT record ownership to prevent conflicts between environments
    {
      name  = "txtOwnerId"
      value = var.cluster_name
    },
    # Policy: sync creates and deletes records (vs. upsert-only)
    {
      name  = "policy"
      value = "sync"
    },
    # Watch Ingress resources
    {
      name  = "sources[0]"
      value = "ingress"
    },
    {
      name  = "sources[1]"
      value = "service"
    },
    # IRSA annotation
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.external_dns.arn
    },
    # Resource requests
    {
      name  = "resources.requests.cpu"
      value = "50m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    },
    # Tolerate system node taint
    {
      name  = "tolerations[0].key"
      value = "CriticalAddonsOnly"
    },
    {
      name  = "tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "tolerations[0].effect"
      value = "NoSchedule"
    },
  ]
}

# =============================================================================
# external-secrets
# =============================================================================

# IRSA role the operator assumes to read secrets from AWS Secrets Manager.
# Same shape as your cert-manager/external-dns roles. The data sources it uses
# (aws_caller_identity, aws_region) already exist at the top of this module.
resource "aws_iam_role" "external_secrets" {
  name = "${var.cluster_name}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = var.cluster_oidc_provider_arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
            # ESO's controller service account, created by the chart below
            "${var.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "read-observability-secrets"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        # Scoped to observability/* only. Broaden this prefix as ESO is given
        # more secret paths to manage elsewhere.
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:observability/*"
      }
    ]
  })
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.6.0" # CHART version (see note); verify the current one before pinning
  namespace        = "external-secrets"
  create_namespace = true

  set = [
    {
      name  = "installCRDs"
      value = "true" # value key can change across major versions — confirm with `helm show values`
    },
    # IRSA: annotate ESO's controller service account with the role above so it
    # reads Secrets Manager with no static keys (identical mechanism to cert-manager).
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.external_secrets.arn
    },
  ]
}