# AWS DevOps Agent — one self-contained agent space per account.
#
# Why per-account instead of a central "hub" space monitoring test+prod as
# source accounts:
#   * Slack channels attach to an agent *space*, not to a monitored account.
#     One space per environment is the only clean way to get "test findings
#     → #cg-alerts-test, prod findings → #cg-alerts-prod".
#   * No cross-account trust: each space's roles can only be assumed by the
#     service *for this account's space* (see the SourceArn conditions below),
#     so a compromise of the test setup tells an attacker nothing about prod.
#   * It mirrors how the rest of this repo works: one root per account, no
#     shared blast radius.
#
# The service works like this: an "agent space" is the agent's home. The
# service principal (aidevops.amazonaws.com) assumes the *agent-space role*
# to discover topology (via Resource Explorer) and investigate incidents; the
# *operator-app role* is what the web app uses when a human reviews
# investigations and chats with the agent. Accounts/integrations are wired to
# the space through "associations".

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # awscc resources don't inherit the aws provider's default_tags — the two
  # providers share nothing. Restate the same tags explicitly.
  tags = [
    { key = "ManagedBy", value = "opentofu" },
    { key = "Environment", value = var.environment },
    { key = "Project", value = "infrastructure" },
  ]
}

# =============================================================================
# Role 1/2: agent-space role — what the agent itself runs as
# =============================================================================
# Trust: only the DevOps Agent service principal, and only when it's acting
# on behalf of an agent space *in this account and region*. The two Condition
# keys are confused-deputy protection — without them, anyone else's agent
# space could ask the service to assume our role. SourceArn uses agentspace/*
# because the role must exist before the space does (the space creation
# validates it), so the exact space ID isn't known yet.
resource "aws_iam_role" "agent_space" {
  name = "DevOpsAgentRole-AgentSpace-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "aidevops.amazonaws.com" }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:aidevops:${var.agent_region}:${local.account_id}:agentspace/*"
          }
        }
      }
    ]
  })
}

# AWS-managed policy: read/investigate access across the account plus what
# the agent needs to run investigations. Managed — AWS extends it as the
# service grows, which we want here (an investigation agent that can't see a
# new service type is useless).
resource "aws_iam_role_policy_attachment" "agent_space_managed" {
  role       = aws_iam_role.agent_space.name
  policy_arn = "arn:aws:iam::aws:policy/AIDevOpsAgentAccessPolicy"
}

# Topology discovery is built on Resource Explorer, whose service-linked role
# may not exist yet in this account. The managed policy doesn't include the
# permission to create it, so AWS's onboarding adds this narrowly-scoped
# inline statement: exactly one action on exactly one role ARN.
resource "aws_iam_role_policy" "agent_space_slr" {
  name = "AllowCreateServiceLinkedRoles"
  role = aws_iam_role.agent_space.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCreateServiceLinkedRoles"
        Effect = "Allow"
        Action = ["iam:CreateServiceLinkedRole"]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/aws-service-role/resource-explorer-2.amazonaws.com/AWSServiceRoleForResourceExplorer"
        ]
      }
    ]
  })
}

# =============================================================================
# Role 2/2: operator-app role — what the web app uses on a human's behalf
# =============================================================================
# Separate from the agent-space role on purpose (segregation of duties): the
# agent's investigation permissions and the human console's permissions can
# be reasoned about — and revoked — independently. Extra sts:TagSession is
# how the service stamps the session with the AgentSpaceId principal tag that
# the managed policy's conditions key off.
resource "aws_iam_role" "operator_app" {
  name = "DevOpsAgentRole-Operator-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "aidevops.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession"]
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:aidevops:${var.agent_region}:${local.account_id}:agentspace/*"
          }
        }
      }
    ]
  })
}

# Managed policy scoped to the operator app: investigations, recommendations,
# knowledge, chat. Access is fenced to the specific agent space via the
# aws:PrincipalTag/AgentSpaceId condition inside the policy.
resource "aws_iam_role_policy_attachment" "operator_app_managed" {
  role       = aws_iam_role.operator_app.name
  policy_arn = "arn:aws:iam::aws:policy/AIDevOpsOperatorAppAccessPolicy"
}

# =============================================================================
# Agent space
# =============================================================================
# IAM is eventually consistent; agent-space creation validates the operator
# role's trust policy server-side and fails if the role hasn't propagated
# yet. AWS's own Terraform sample inserts this same 30s pause. If creation
# still races, a re-apply picks up where it left off.
resource "time_sleep" "iam_propagation" {
  create_duration = "30s"

  depends_on = [
    aws_iam_role_policy_attachment.agent_space_managed,
    aws_iam_role_policy.agent_space_slr,
    aws_iam_role_policy_attachment.operator_app_managed,
  ]
}

resource "awscc_devopsagent_agent_space" "this" {
  name        = var.agent_space_name
  description = var.agent_space_description
  kms_key_arn = var.kms_key_arn

  # Operator app auth = IAM Identity Center: log in to the web app with the
  # same SSO identity used everywhere else, instead of juggling IAM
  # credentials in a browser.
  operator_app = {
    idc = {
      idc_instance_arn      = var.idc_instance_arn
      operator_app_role_arn = aws_iam_role.operator_app.arn
    }
  }

  tags = local.tags

  depends_on = [time_sleep.iam_propagation]
}

# =============================================================================
# Associations
# =============================================================================

# Wire this account to its own space. account_type "monitor" marks it as the
# primary account (topology discovery runs here); "source" would be a foreign
# account monitored cross-account — which we deliberately don't do.
resource "awscc_devopsagent_association" "aws_monitor" {
  agent_space_id = awscc_devopsagent_agent_space.this.agent_space_id
  service_id     = "aws"

  configuration = {
    aws = {
      account_id         = local.account_id
      account_type       = "monitor"
      assumable_role_arn = aws_iam_role.agent_space.arn
    }
  }
}

# Slack channel for this environment's findings. Created only once the
# manual, console-only workspace OAuth registration has been done and the
# resulting IDs are in tfvars (see variables.tf). Channel-per-environment is
# the point of the per-account space design above.
resource "awscc_devopsagent_association" "slack" {
  count = var.slack_service_id != "" ? 1 : 0

  agent_space_id = awscc_devopsagent_agent_space.this.agent_space_id
  service_id     = var.slack_service_id

  configuration = {
    slack = {
      workspace_id   = var.slack_workspace_id
      workspace_name = var.slack_workspace_name
      # The provider calls this incident_response_target; it maps to the
      # API's opsOncallTarget — the on-call agent's findings channel.
      transmission_target = {
        incident_response_target = {
          channel_id   = var.slack_oncall_channel_id
          channel_name = var.slack_oncall_channel_name
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.slack_workspace_id != "" && var.slack_oncall_channel_id != ""
      error_message = "slack_service_id is set, so slack_workspace_id and slack_oncall_channel_id must be set too (all three come out of the console registration step)."
    }
  }
}
