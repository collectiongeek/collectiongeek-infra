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

  environment        = var.environment
  cluster_name       = var.cluster_name
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

  instance_types = ["t3.medium", "t3.large", "m6i.large", "m6a.large", "c6i.large", "c6a.large"]
  capacity_type  = ["spot", "on-demand"]
  cpu_limit      = "20"
  memory_limit   = "40Gi"
}

# =============================================================================
# Cluster Add-ons will be added in Phase 6
# =============================================================================