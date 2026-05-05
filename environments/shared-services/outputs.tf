output "state_bucket_name" {
  description = "S3 bucket name for OpenTofu state"
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "S3 bucket ARN for OpenTofu state"
  value       = aws_s3_bucket.state.arn
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.state_lock.name
}

output "state_access_role_arn" {
  description = "IAM role ARN for cross-account state access"
  value       = aws_iam_role.state_access.arn
}

output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_nameservers" {
  description = "Route 53 nameservers (set these at your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

output "shared_services_account_id" {
  description = "SharedServices AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "dns_manager_role_arn" {
  description = "IAM role ARN for external-dns cross-account Route 53 access"
  value       = aws_iam_role.dns_manager.arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager cross-account Route 53 access"
  value       = aws_iam_role.cert_manager.arn
}

data "aws_caller_identity" "current" {}