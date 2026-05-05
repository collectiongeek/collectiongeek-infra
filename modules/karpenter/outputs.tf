output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_nodepool_name" {
  description = "Name of the default Karpenter NodePool"
  value       = "default"
}