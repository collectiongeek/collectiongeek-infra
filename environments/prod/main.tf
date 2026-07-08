# =============================================================================
# Local values
# =============================================================================

locals {
  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
  ]
  private_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 10),
    cidrsubnet(var.vpc_cidr, 8, 11),
  ]
}

# =============================================================================
# VPC — Multi-AZ NAT for high availability
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  cluster_name         = var.cluster_name
  single_nat_gateway   = false # One NAT Gateway per AZ for HA
}

# =============================================================================
# EKS Cluster — Larger system node group
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  environment        = var.environment
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  system_node_instance_types = ["t3.medium"]
  system_node_desired_size   = 2 # 2 system nodes for HA
  system_node_min_size       = 2
  system_node_max_size       = 3
}

# =============================================================================
# Karpenter — Higher limits, on-demand priority
# =============================================================================

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name              = module.eks.cluster_name
  cluster_endpoint          = module.eks.cluster_endpoint
  cluster_oidc_provider_arn = module.eks.cluster_oidc_provider_arn
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  node_role_arn             = module.eks.node_role_arn
  node_role_name            = module.eks.node_role_name
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.eks.cluster_security_group_id

  # Pinned explicitly so module-default changes never move prod implicitly.
  # Promote only after validation in test (apply test before prod).
  karpenter_version = "1.12.1"

  instance_types = ["t3.medium", "t3.large", "m6i.large", "m6a.large", "c6i.large", "c6a.large"]
  capacity_type  = ["on-demand", "spot"] # On-demand first for prod stability
  cpu_limit      = "40"                  # Double the test limit
  memory_limit   = "80Gi"
}

# =============================================================================
# Cluster Add-ons (Ingress, cert-manager, external-dns)
# =============================================================================

module "cluster_addons" {
  source = "../../modules/cluster-addons"

  environment                = var.environment
  cluster_name               = module.eks.cluster_name
  cluster_oidc_provider_arn  = module.eks.cluster_oidc_provider_arn
  cluster_oidc_issuer_url    = module.eks.cluster_oidc_issuer_url
  domain_name                = var.domain_name
  route53_zone_id            = var.route53_zone_id
  dns_manager_role_arn       = var.dns_manager_role_arn
  cert_manager_role_arn      = var.cert_manager_role_arn
  shared_services_account_id = var.shared_services_account_id

  depends_on = [module.karpenter]
}

# =============================================================================
# GitHub Actions OIDC (CI bootstrap)
# =============================================================================
# Creates the GitHub OIDC provider in this account and a role the `infra`
# workflow's `prod` job assumes. First apply is from a laptop (one-time
# bootstrap exception to the "never apply prod from a laptop" rule); after
# that, CI manages itself. Paste module.github_oidc.role_arn into the
# `production` GitHub Environment's AWS_ROLE_ARN secret.
module "github_oidc" {
  source      = "../../modules/github-oidc"
  github_org  = "collectiongeek"
  github_repo = "collectiongeek-infra"

  # Both prod CI jobs assume this one role: the ungated prod-plan job runs in
  # the "production-plan" Environment and the gated prod-apply job in
  # "production", so the trust policy must allow both. Each name must match a
  # workflow `environment:` key exactly. See .github/workflows/infra.yml.
  github_environment_names = ["production", "production-plan"]

  # TODO(security): tighten to a narrower policy once IAM Access Analyzer has
  # observed enough CI runs to generate a per-service policy. AdministratorAccess
  # is the deliberate bootstrap choice — see PHASE-0 §0.6 for rationale.
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

# Grant the CI role kubernetes-API access to this cluster. Without this,
# kubectl_manifest and helm_release resources fail with 401 — EKS only
# auto-authorises the IAM identity that created the cluster.
# Access entries are the modern replacement for the aws-auth ConfigMap;
# they work alongside it under
# authentication_mode = "API_AND_CONFIG_MAP" (set in modules/eks/main.tf).
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_oidc.role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.github_oidc.role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# =============================================================================
# Argo CD
# =============================================================================

module "argocd" {
  source = "../../modules/argocd"

  environment       = var.environment
  domain_name       = var.domain_name
  cluster_issuer    = "letsencrypt-prod"
  gitops_repo_url   = var.gitops_repo_url
  slack_webhook_url = var.slack_webhook_url

  # WorkOS SSO (Portal SSO doc §S.3). Client ID and issuer are public; the
  # client secret flows Secrets Manager -> ESO (observability/argocd-oidc).
  oidc_issuer      = "https://polished-paper-76.authkit.app"
  oidc_client_id   = "client_01KWZKRV9CV5J84YE9QF58G4T0"
  oidc_admin_email = "29parsecs.dubious@icloud.com"

  # §S.5 lock (SSO verified both envs 2026-07-08): WorkOS is the only door.
  # BREAK-GLASS: flip back to true (or delete the line) to restore the local
  # admin password login.
  local_admin_enabled = false

  # Pinned explicitly so module-default changes never move prod implicitly.
  # Promote only after validation in test (apply test before prod).
  # NOTE: 7.x -> 9.x crosses two chart majors (Argo CD 2.x -> 3.x). The
  # server.insecure mechanism switches automatically (see modules/argocd).
  argocd_chart_version = "9.5.16"

  # Keep 2.x tracking behavior across the 3.x upgrade; migrate to "annotation"
  # later as its own change once 3.x is confirmed healthy.
  resource_tracking_method = "label"

  depends_on = [module.cluster_addons]
}