variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
}

variable "cluster_issuer" {
  description = "cert-manager ClusterIssuer name for TLS"
  type        = string
  default     = "letsencrypt-prod"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.8.13"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for Argo CD notifications (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitops_repo_url" {
  description = "GitOps repository URL"
  type        = string
}