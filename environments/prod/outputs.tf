# VPC outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# EKS outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.cluster_oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL (without https://)"
  value       = module.eks.cluster_oidc_issuer_url
}

# Argo CD outputs
output "argocd_url" {
  description = "Argo CD UI URL"
  value       = module.argocd.argocd_url
}

# Observability
output "loki_role_arn" {
  description = "IAM role ARN for the loki service account (IRSA)."
  value       = module.observability.loki_role_arn
}

output "tempo_role_arn" {
  description = "IAM role ARN for the tempo service account (IRSA)."
  value       = module.observability.tempo_role_arn
}

output "loki_bucket_name" {
  description = "S3 bucket name for Loki chunks."
  value       = module.observability.loki_bucket_name
}

output "tempo_bucket_name" {
  description = "S3 bucket name for Tempo traces."
  value       = module.observability.tempo_bucket_name
}

# GitHub Actions OIDC
output "github_actions_role_arn" {
  description = "IAM role ARN that the infra workflow's prod job assumes via GitHub OIDC."
  value       = module.github_oidc.role_arn
}