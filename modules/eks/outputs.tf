output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64 encoded)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL for IRSA"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "IAM role ARN for node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_role_name" {
  description = "IAM role name for node groups"
  value       = aws_iam_role.node_group.name
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL without https:// prefix (for IRSA trust policies)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}