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
# VPC
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  cluster_name         = var.cluster_name
  single_nat_gateway   = true
}

# =============================================================================
# EKS Cluster
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  environment  = var.environment
  cluster_name = var.cluster_name
  # TODO(k8s-1.36): bump terraform.tfvars `kubernetes_version` to "1.36" (minor
  # only — EKS rejects patch-level "1.36.1") once EKS offers it. As of 2026-05
  # EKS standard support tops out at 1.35; Karpenter's matrix also stops at 1.35.
  # After the bump: upgrade the system node group + cluster default addons
  # (coredns/kube-proxy/vpc-cni) to stay within version skew.
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  system_node_instance_types = ["t3.medium"]
  system_node_desired_size   = 1
  system_node_min_size       = 1
  system_node_max_size       = 2
}

# =============================================================================
# Karpenter
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

  # Pin chart version per-environment so this bump stays isolated to test.
  # (The module default still serves prod — do not change it there.)
  karpenter_version = "1.12.1"

  # Test has a single system node, and Karpenter runs only on system nodes
  # (one pod per host). Run a single replica so rolling upgrades complete
  # instead of hanging on an unschedulable surge pod.
  replicas = 1

  instance_types = ["t3.medium", "t3.large", "m6i.large", "m6a.large", "c6i.large", "c6a.large"]
  capacity_type  = ["spot", "on-demand"]
  cpu_limit      = "20"
  memory_limit   = "40Gi"
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
# workflow's `test` job assumes. First apply is from a laptop (the role
# doesn't exist yet, so CI can't run); after that, CI manages itself.
# Paste module.github_oidc.role_arn into the `test` GitHub Environment's
# AWS_ROLE_ARN secret.
module "github_oidc" {
  source                  = "../../modules/github-oidc"
  github_org              = "collectiongeek"
  github_repo             = "collectiongeek-infra"
  github_environment_name = "test" # must match the workflow's `environment:` key
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

  # Pin chart version per-environment so this major bump (7.x -> 9.x, i.e.
  # Argo CD 2.x -> 3.x) stays isolated to test. Prod keeps the module default.
  # NOTE: crosses two chart majors — review the 2.14->3.0 upgrade notes and
  # back up Applications before applying. See modules/argocd/main.tf for the
  # `server.insecure` param change required by chart 8.x+.
  argocd_chart_version = "9.5.16"

  # Keep 2.x tracking behavior across the 3.x upgrade; migrate to "annotation"
  # later as its own change once 3.x is confirmed healthy.
  resource_tracking_method = "label"

  depends_on = [module.cluster_addons]
}