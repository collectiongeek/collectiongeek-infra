output "role_arn" {
  description = "ARN of the IAM role GitHub Actions will assume. Paste this into the matching GitHub Environment's AWS_ROLE_ARN secret."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}
