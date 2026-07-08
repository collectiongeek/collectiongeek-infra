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
variable "oidc_issuer" {
  description = "WorkOS AuthKit domain issuer for Argo CD SSO, e.g. https://<subdomain>.authkit.app (Portal SSO doc §S.3). Empty = OIDC not configured."
  type        = string
  default     = ""
}

variable "oidc_client_id" {
  description = "WorkOS Connect OAuth-app client ID for Argo CD SSO (public; the matching client secret arrives via ESO from observability/argocd-oidc)."
  type        = string
  default     = ""
}

variable "oidc_admin_email" {
  description = "Sole identity mapped to role:admin in Argo CD RBAC. Everyone else who can authenticate gets NO role (policy.default is empty) — see Portal SSO doc §S.1."
  type        = string
  default     = ""
}

variable "local_admin_enabled" {
  description = "Keep Argo CD's local admin password login enabled. Set false only after WorkOS SSO is verified (Portal SSO doc §S.5) — flipping back to true is the break-glass path."
  type        = bool
  default     = true
}
