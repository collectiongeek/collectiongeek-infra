module "observability" {
  source                  = "../../modules/observability"
  cluster_name            = var.cluster_name
  vpc_id                  = module.vpc.vpc_id
  private_route_table_ids = module.vpc.private_route_table_ids
  oidc_provider_arn       = module.eks.cluster_oidc_provider_arn
  oidc_provider_url       = module.eks.cluster_oidc_issuer_url
  slack_webhook_url       = var.observability_slack_webhook_url
}