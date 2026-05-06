variable "aws_profile" {
  description = "AWS CLI profile for the Production account"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "shared_services_account_id" {
  description = "AWS account ID for SharedServices (used for cross-account access)"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID (from SharedServices)"
  type        = string
}

variable "dns_manager_role_arn" {
  description = "IAM role ARN for external-dns Route 53 access (from SharedServices)"
  type        = string
}

variable "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager Route 53 access (from SharedServices)"
  type        = string
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for Argo CD notifications (optional)"
  type        = string
  default     = ""
  sensitive   = true
}