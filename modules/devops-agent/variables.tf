variable "environment" {
  description = "Environment name (test | prod). Used in role/space names and tags."
  type        = string
}

variable "agent_region" {
  description = <<-EOT
    Region the agent space lives in. MUST match the region the caller's awscc
    provider is configured with — it's baked into the IAM trust policies'
    aws:SourceArn condition, so a mismatch produces roles the service can
    never assume. DevOps Agent is only offered in six regions (us-east-1,
    us-west-2, ap-southeast-2, ap-northeast-1, eu-central-1, eu-west-1);
    we use us-west-2, the closest to our us-west-1 workloads. The agent
    discovers resources cross-region via Resource Explorer, so living in
    us-west-2 doesn't stop it from seeing the us-west-1 clusters.
  EOT
  type        = string
}

variable "agent_space_name" {
  description = "Name of the DevOps Agent space (shown in the console and operator app)."
  type        = string
}

variable "agent_space_description" {
  description = "Human-readable purpose of the agent space."
  type        = string
  default     = ""
}

variable "operator_auth_mode" {
  description = <<-EOT
    How humans sign in to the operator web app: "iam" (open it from the
    console via an assumed role; 30-minute sessions) or "idc" (IAM Identity
    Center SSO; 8-hour sessions). HARD CONSTRAINT discovered during rollout:
    idc only works if the Identity Center *instance* lives in the SAME region
    as the agent space — and our org instance lives in us-west-1, which is
    not a DevOps Agent region. So iam is the working default; idc remains
    supported for a future account-instance or re-homed-IdC setup.
  EOT
  type        = string
  default     = "iam"

  validation {
    condition     = contains(["iam", "idc"], var.operator_auth_mode)
    error_message = "operator_auth_mode must be \"iam\" or \"idc\"."
  }
}

variable "idc_instance_arn" {
  description = "IAM Identity Center instance ARN (from `aws sso-admin list-instances`). Only used — and required — when operator_auth_mode is \"idc\". The instance MUST live in the same region as the agent space (agent_region)."
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for encrypting agent space data. Null = AWS-owned key. TODO(security): create a CMK once we've reviewed the key-policy grants DevOps Agent needs (userguide: Data protection > Encryption at rest)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Slack (optional until the one-time console OAuth registration is done)
# ---------------------------------------------------------------------------
# Registering the Slack *workspace* is a manual console step (OAuth redirect
# to Slack) that no API or provider can perform. It yields a service ID and
# workspace ID; once those exist, the *channel* wiring below is plain IaC.
# Leave slack_service_id empty to skip the association on first apply.

variable "slack_service_id" {
  description = "Service ID of the registered Slack integration (from `aws devops-agent list-services`, serviceType `slack`). Empty = skip the Slack association."
  type        = string
  default     = ""
}

variable "slack_workspace_id" {
  description = "Slack workspace ID (starts with T; shown after console registration)."
  type        = string
  default     = ""
}

variable "slack_workspace_name" {
  description = "Slack workspace name (as registered)."
  type        = string
  default     = ""
}

variable "slack_oncall_channel_id" {
  description = "Slack channel ID (starts with C) where the on-call agent posts investigation findings for THIS environment. Distinct per environment by design."
  type        = string
  default     = ""
}

variable "slack_oncall_channel_name" {
  description = "Slack channel name matching slack_oncall_channel_id (e.g. cg-alerts-test)."
  type        = string
  default     = ""
}
