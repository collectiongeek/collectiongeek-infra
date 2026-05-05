# =============================================================================
# Local values
# =============================================================================

locals {
  # Derive subnet CIDRs from the VPC CIDR
  # For 10.0.0.0/16:
  #   Public:  10.0.1.0/24, 10.0.2.0/24
  #   Private: 10.0.10.0/24, 10.0.11.0/24
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
  single_nat_gateway   = true  # Cost savings for test
}

# =============================================================================
# EKS, Karpenter, and Cluster Add-ons will be added in subsequent phases
# =============================================================================