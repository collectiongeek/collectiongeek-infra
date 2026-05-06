# =============================================================================
# Locals
# =============================================================================

locals {
  argocd_host = var.environment == "prod" ? "argocd.${var.domain_name}" : "argocd.${var.environment}.${var.domain_name}"
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

  # Primary hostname — in chart v7.x this controls all ingress rules and TLS
  set {
    name  = "global.domain"
    value = local.argocd_host
  }

  # Server ingress
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "server.ingress.tls"
    value = "true"
  }
  set {
    name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = var.cluster_issuer
  }

  # Force HTTPS redirect
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "true"
  }

  # Run Argo CD server in insecure mode (TLS terminated at ingress)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Tolerate system node taint for all components
  # Server
  set {
    name  = "server.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "server.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "server.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Repo server
  set {
    name  = "repoServer.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "repoServer.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "repoServer.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Application controller
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

  # Redis
  set {
    name  = "redis.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "redis.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "redis.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Dex
  set {
    name  = "dex.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "dex.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "dex.tolerations[0].effect"
    value = "NoSchedule"
  }

  # ApplicationSet controller
  set {
    name  = "applicationSet.tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "applicationSet.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "applicationSet.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Resource requests
  set {
    name  = "server.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }

  # GitOps repository
  set {
    name  = "configs.repositories.gitops-repo.url"
    value = var.gitops_repo_url
  }
  set {
    name  = "configs.repositories.gitops-repo.type"
    value = "git"
  }
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

  set {
    name  = "secret.items.slack-token"
    value = var.slack_webhook_url
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

  depends_on = [helm_release.argocd]
}