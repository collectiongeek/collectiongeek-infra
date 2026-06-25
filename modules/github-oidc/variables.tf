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
  description = "Managed IAM policies to attach to the role. Defaults to AdministratorAccess for bootstrap — tighten later (e.g. via Access Analyzer-generated policy)."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
