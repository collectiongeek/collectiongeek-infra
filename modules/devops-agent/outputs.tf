output "agent_space_id" {
  description = "ID of the agent space (needed for `aws devops-agent` CLI calls and imports)."
  value       = awscc_devopsagent_agent_space.this.agent_space_id
}

output "agent_space_arn" {
  description = "ARN of the agent space."
  value       = awscc_devopsagent_agent_space.this.arn
}

output "agent_space_role_arn" {
  description = "IAM role the DevOps Agent service assumes to investigate this account."
  value       = aws_iam_role.agent_space.arn
}

output "operator_app_role_arn" {
  description = "IAM role the operator web app uses on behalf of signed-in humans."
  value       = aws_iam_role.operator_app.arn
}

output "idc_application_arn" {
  description = "Identity Center application created for the operator app (assign users/groups to it in the Identity Center console)."
  value       = try(awscc_devopsagent_agent_space.this.operator_app.idc.idc_application_arn, null)
}
