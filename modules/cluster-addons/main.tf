# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# NGINX Ingress Controller
# =============================================================================

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.12.0"
  create_namespace = true

  # Use NLB (Network Load Balancer) instead of CLB
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  # Resource requests for Karpenter scheduling
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Tolerate system node taint so it can run on system nodes too
  set {
    name  = "controller.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "controller.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "controller.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Replica count
  set {
    name  = "controller.replicaCount"
    value = var.environment == "prod" ? "2" : "1"
  }
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

  # Install CRDs
  set {
    name  = "crds.enabled"
    value = "true"
  }

  # IRSA annotation
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager.arn
  }

  # Resource requests
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # Tolerate system node taint
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
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

  # AWS provider configuration
  set {
    name  = "provider.name"
    value = "aws"
  }

  # Use the cross-account role for Route 53 access
  set {
    name  = "extraArgs[0]"
    value = "--aws-assume-role=${var.dns_manager_role_arn}"
  }

  # Only manage records for our domain
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }

  # TXT record ownership to prevent conflicts between environments
  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  # Policy: sync creates and deletes records (vs. upsert-only)
  set {
    name  = "policy"
    value = "sync"
  }

  # Watch Ingress resources
  set {
    name  = "sources[0]"
    value = "ingress"
  }
  set {
    name  = "sources[1]"
    value = "service"
  }

  # IRSA annotation
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  # Resource requests
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # Tolerate system node taint
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}