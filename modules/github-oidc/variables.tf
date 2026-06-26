variable "github_org" {
  description = "GitHub org or user that owns the repo (the part before the slash)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (the part after the slash)."
  type        = string
}

variable "github_environment_name" {
  description = "GitHub Environment name in the workflow's `environment:` key — e.g. \"test\" or \"production\". Must match exactly; this is the string the OIDC token's `sub` claim will contain."
  type        = string
}

variable "role_name" {
  description = "IAM role name for GitHub Actions to assume."
  type        = string
  default     = "github-actions-infra"
}

variable "managed_policy_arns" {
  description = "Managed IAM policy ARNs to attach to the role. Required — no default, so each consumer makes the trust-boundary choice visible at its module call site (admin vs. narrower). Pair with inline `aws_iam_role_policy` if you need finer scoping."
  type        = list(string)
}
