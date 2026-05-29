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

variable "resource_tracking_method" {
  description = <<-EOT
    Argo CD resource tracking method. Null (default) uses the application
    default, which is "label" in Argo CD 2.x and "annotation" in 3.x. Pin to
    "label" across a 2.x -> 3.x upgrade to keep tracking behavior unchanged,
    then migrate to "annotation" deliberately as a separate change.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.resource_tracking_method == null || contains(["label", "annotation", "annotation+label"], var.resource_tracking_method)
    error_message = "resource_tracking_method must be one of: label, annotation, annotation+label (or null)."
  }
}