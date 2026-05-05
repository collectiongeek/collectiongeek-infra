variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL without https:// prefix"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID (in SharedServices account)"
  type        = string
}

variable "dns_manager_role_arn" {
  description = "IAM role ARN for external-dns cross-account Route 53 access (in SharedServices)"
  type        = string
}

variable "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager cross-account Route 53 access (in SharedServices)"
  type        = string
}

variable "shared_services_account_id" {
  description = "SharedServices AWS account ID"
  type        = string
}