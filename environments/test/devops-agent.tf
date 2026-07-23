# =============================================================================
# AWS DevOps Agent (agentic SRE — investigates incidents, posts to Slack)
# =============================================================================
# One agent space per account (see modules/devops-agent/main.tf for the full
# rationale): this one monitors only the Test account and posts findings to
# the test Slack channel. Prod has its own twin.
#
# Gated behind devops_agent_enabled so this file can merge before the GitHub
# Environment vars/secrets exist — CI plans stay green with the module off.
# Rollout order (details in the Observability doc "AWS DevOps Agent"):
#   1. set DEVOPS_AGENT_ENABLED + IDC ARN → first apply creates roles + space
#   2. register Slack in the console (one-time OAuth, can't be IaC)
#   3. set the Slack service/workspace/channel IDs → second apply wires Slack
module "devops_agent" {
  count  = var.devops_agent_enabled ? 1 : 0
  source = "../../modules/devops-agent"

  environment             = var.environment
  agent_region            = var.devops_agent_region
  agent_space_name        = "collectiongeek-${var.environment}"
  agent_space_description = "DevOps Agent space for the CollectionGeek ${var.environment} account (self-monitoring; Slack: ${var.devops_agent_slack_channel_name != "" ? var.devops_agent_slack_channel_name : "not wired yet"})"

  operator_auth_mode = var.devops_agent_operator_auth_mode
  idc_instance_arn   = var.devops_agent_idc_instance_arn

  slack_service_id          = var.devops_agent_slack_service_id
  slack_workspace_id        = var.devops_agent_slack_workspace_id
  slack_workspace_name      = var.devops_agent_slack_workspace_name
  slack_oncall_channel_id   = var.devops_agent_slack_channel_id
  slack_oncall_channel_name = var.devops_agent_slack_channel_name
}
