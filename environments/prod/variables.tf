variable "aws_profile" {
  description = "AWS CLI profile for the Production account. Local laptop apply only — leave empty in CI, where env-var creds from the configure-aws-credentials OIDC action are used."
  type        = string
  default     = ""
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

variable "observability_slack_webhook_url" {
  description = "Slack webhook for Grafana Alertmanager alerts (optional). Separate from slack_webhook_url, which is the Argo CD notifications webhook (different channel)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "healthchecks_ping_url" {
  description = "healthchecks.io ping URL for the Alertmanager dead-man's switch (optional; Phase 4 doc §4.4)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_oidc_client_secret" {
  description = "WorkOS OAuth-app client secret for Grafana SSO (optional; Portal SSO doc §S.3)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_oidc_client_secret" {
  description = "WorkOS OAuth-app client secret for Argo CD SSO (optional; Portal SSO doc §S.3)."
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# AWS DevOps Agent (devops-agent.tf). All values arrive via GitHub Environment
# vars/secrets in CI (TF_VAR_*) or terraform.tfvars on a laptop.
# -----------------------------------------------------------------------------

variable "devops_agent_enabled" {
  description = "Master switch for the DevOps Agent module. Defaults off so the code can merge before the GitHub Environment vars/secrets exist; flip the DEVOPS_AGENT_ENABLED Environment var to \"true\" to roll out."
  type        = bool
  default     = false
}

variable "devops_agent_region" {
  description = "Region hosting the agent space. DevOps Agent isn't offered in us-west-1; us-west-2 is the closest supported region. Must be one of: us-east-1, us-west-2, ap-southeast-2, ap-northeast-1, eu-central-1, eu-west-1."
  type        = string
  default     = "us-west-2"
}

variable "devops_agent_idc_instance_arn" {
  description = "IAM Identity Center instance ARN for operator-app SSO (from `aws sso-admin list-instances`). Required once devops_agent_enabled is true."
  type        = string
  default     = ""
}

variable "devops_agent_slack_service_id" {
  description = "Service ID of the console-registered Slack integration (`aws devops-agent list-services`, serviceType `slack`). Empty until the one-time OAuth registration is done — the Slack association is skipped meanwhile."
  type        = string
  default     = ""
}

variable "devops_agent_slack_workspace_id" {
  description = "Slack workspace ID (T…) from the console registration."
  type        = string
  default     = ""
}

variable "devops_agent_slack_workspace_name" {
  description = "Slack workspace name as registered."
  type        = string
  default     = ""
}

variable "devops_agent_slack_channel_id" {
  description = "Slack channel ID (C…) receiving THIS environment's agent findings. Each environment posts to its own channel on purpose — see devops-agent.tf."
  type        = string
  default     = ""
}

variable "devops_agent_slack_channel_name" {
  description = "Slack channel name matching devops_agent_slack_channel_id."
  type        = string
  default     = ""
}
