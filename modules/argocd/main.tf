# =============================================================================
# Locals
# =============================================================================

locals {
  argocd_host = var.environment == "prod" ? "argocd.${var.domain_name}" : "argocd.${var.environment}.${var.domain_name}"

  # How to enable insecure server mode depends on the chart major version:
  #   chart < 8.x : the `--insecure` server arg
  #   chart >= 8.x: configs.params "server.insecure" (the chart derives the
  #                 server port from this param; the arg is ignored)
  # Keying off the chart version keeps each environment byte-identical until its
  # own chart version is deliberately bumped.
  argocd_chart_major         = tonumber(split(".", var.argocd_chart_version)[0])
  argocd_insecure_via_params = local.argocd_chart_major >= 8

  # WorkOS SSO (Portal SSO doc §S.3). All three inputs or nothing — a partial
  # config would render a broken login button.
  oidc_enabled = var.oidc_issuer != "" && var.oidc_client_id != "" && var.oidc_admin_email != ""

  # oidc.config + RBAC go through helm `values` (multiline YAML strings do not
  # survive `set` encoding; `set` entries still win on conflict, so the two
  # mechanisms compose). The client secret is never in this file: Argo CD
  # resolves `$argocd-oidc:client-secret` at runtime from the ESO-synced
  # Secret below (the `$<secret>:<key>` syntax requires that Secret to carry
  # the app.kubernetes.io/part-of: argocd label).
  oidc_values = local.oidc_enabled ? [
    yamlencode({
      configs = {
        cm = {
          "oidc.config" = <<-EOT
            name: WorkOS
            issuer: ${var.oidc_issuer}
            clientID: ${var.oidc_client_id}
            clientSecret: $argocd-oidc:client-secret
            requestedScopes: ["openid", "profile", "email"]
          EOT
        }
        rbac = {
          # Authenticated ≠ authorized: app end-users share the WorkOS pool,
          # so the default role is EMPTY and exactly one identity is admin.
          "policy.default" = ""
          "policy.csv"     = "g, ${var.oidc_admin_email}, role:admin\n"
          "scopes"         = "[email]"
        }
      }
      # The OIDC client secret, synced from Secrets Manager by ESO. Riding
      # extraObjects keeps Argo CD's whole SSO story inside this module.
      extraObjects = [{
        apiVersion = "external-secrets.io/v1"
        kind       = "ExternalSecret"
        metadata = {
          name      = "argocd-oidc"
          namespace = "argocd"
        }
        spec = {
          refreshInterval = "1h"
          secretStoreRef  = { name = "aws-secretsmanager", kind = "ClusterSecretStore" }
          target = {
            name = "argocd-oidc"
            template = {
              metadata = {
                labels = { "app.kubernetes.io/part-of" = "argocd" }
              }
            }
          }
          data = [{
            secretKey = "client-secret"
            remoteRef = { key = "observability/argocd-oidc", property = "client-secret" }
          }]
        }
      }]
    })
  ] : []
}

# =============================================================================
# Argo CD Helm Release
# =============================================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = true

  # WorkOS SSO (empty list = no-op until the oidc_* variables are set).
  values = local.oidc_values

  # v2 stored `set` as an unordered set; the v3 ordered-list attribute makes the
  # first plan show a one-time reorder of these entries (state is alphabetical)
  # plus new v3 schema attributes. Helm renders identical values either way, so
  # the apply bumps the release revision without changing any workload.
  set = concat([
    # Primary hostname — in chart v7.x this controls all ingress rules and TLS
    {
      name  = "global.domain"
      value = local.argocd_host
    },
    # Server ingress
    {
      name  = "server.ingress.enabled"
      value = "true"
    },
    {
      name  = "server.ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "server.ingress.tls"
      value = "true"
    },
    {
      name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
      value = var.cluster_issuer
    },
    # Force HTTPS redirect (F5 NGINX annotation; replaces the community
    # nginx.ingress.kubernetes.io/force-ssl-redirect, which F5 ignores)
    {
      name  = "server.ingress.annotations.nginx\\.org/redirect-to-https"
      value = "true"
    },
    ],
    # Run Argo CD server in insecure mode (TLS terminated at ingress).
    # Mechanism is chart-version dependent — see local.argocd_insecure_via_params.
    local.argocd_insecure_via_params
    ? [{ name = "configs.params.server\\.insecure", value = "true" }]
    : [{ name = "server.extraArgs[0]", value = "--insecure" }],
    # §S.5 lock: once WorkOS SSO is verified, the local admin account goes
    # away. Break-glass = set local_admin_enabled back to true (one-line PR).
    # The key MUST ride configs.cm (→ argocd-cm, watched live by the settings
    # manager) — in configs.params (→ argocd-cmd-params-cm) it is silently
    # ignored and the password keeps working.
    var.local_admin_enabled ? [] : [
      { name = "configs.cm.admin\\.enabled", value = "false" }
    ],
    # Pin the resource tracking method when set. The app default flips from
    # "label" (2.x) to "annotation" (3.x); pinning avoids a silent change to how
    # live resources are tracked during a chart-major upgrade. Null = app default.
    var.resource_tracking_method == null ? [] : [
      { name = "configs.cm.application\\.resourceTrackingMethod", value = var.resource_tracking_method }
    ],
    [
      # Tolerate system node taint for all components
      # Server
      {
        name  = "server.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "server.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "server.tolerations[0].effect"
        value = "NoSchedule"
      },
      # Repo server
      {
        name  = "repoServer.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "repoServer.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "repoServer.tolerations[0].effect"
        value = "NoSchedule"
      },
      # Application controller
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
      # Redis
      {
        name  = "redis.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "redis.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "redis.tolerations[0].effect"
        value = "NoSchedule"
      },
      # Dex
      {
        name  = "dex.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "dex.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "dex.tolerations[0].effect"
        value = "NoSchedule"
      },
      # ApplicationSet controller
      {
        name  = "applicationSet.tolerations[0].key"
        value = "CriticalAddonsOnly"
      },
      {
        name  = "applicationSet.tolerations[0].operator"
        value = "Exists"
      },
      {
        name  = "applicationSet.tolerations[0].effect"
        value = "NoSchedule"
      },
      # Resource requests
      {
        name  = "server.resources.requests.cpu"
        value = "50m"
      },
      {
        name  = "server.resources.requests.memory"
        value = "128Mi"
      },
      {
        name  = "repoServer.resources.requests.cpu"
        value = "50m"
      },
      {
        name  = "repoServer.resources.requests.memory"
        value = "128Mi"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "100m"
      },
      {
        name  = "controller.resources.requests.memory"
        value = "256Mi"
      },
      # GitOps repository
      {
        name  = "configs.repositories.gitops-repo.url"
        value = var.gitops_repo_url
      },
      {
        name  = "configs.repositories.gitops-repo.type"
        value = "git"
      },
    ]
  )
}

# =============================================================================
# Argo CD Notifications (Slack) — optional
# =============================================================================

resource "helm_release" "argocd_notifications" {
  count = var.slack_webhook_url != "" ? 1 : 0

  name       = "argocd-notifications"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-notifications"
  version    = "1.8.1"

  set = [
    {
      name  = "secret.items.slack-token"
      value = var.slack_webhook_url
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

  depends_on = [helm_release.argocd]
}