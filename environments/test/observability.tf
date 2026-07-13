module "observability" {
  source            = "../../modules/observability"
  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
  slack_webhook_url = var.observability_slack_webhook_url

  healthchecks_ping_url = var.healthchecks_ping_url

  grafana_oidc_client_secret = var.grafana_oidc_client_secret
  argocd_oidc_client_secret  = var.argocd_oidc_client_secret
}