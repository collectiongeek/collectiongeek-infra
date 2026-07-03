variable "github_org" {
  description = "GitHub org or user that owns the repo (the part before the slash)."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (the part after the slash)."
  type        = string
}

variable "github_environment_names" {
  description = "GitHub Environment names allowed to assume this role. Each must match a workflow `environment:` key exactly — it's the string the OIDC token's `sub` claim carries. The trust policy allows any name in the list, so a role shared across e.g. an ungated plan Environment and a gated apply Environment lists both."
  type        = list(string)

  validation {
    condition     = length(var.github_environment_names) > 0
    error_message = "Provide at least one GitHub Environment name; an empty list produces a trust policy that matches nothing and leaves the role unusable."
  }
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
