variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL without https:// prefix"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for Karpenter-launched nodes"
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for Karpenter-launched nodes"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where Karpenter can launch nodes"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Cluster security group ID"
  type        = string
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.12.0"
}

variable "instance_types" {
  description = "Allowed EC2 instance types for Karpenter"
  type        = list(string)
  default     = [
    "t3.medium",
    "t3.large",
    "m6i.large",
    "m6a.large",
    "c6i.large",
    "c6a.large",
  ]
}

variable "capacity_type" {
  description = "Capacity types for Karpenter (spot, on-demand)"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "cpu_limit" {
  description = "Maximum total vCPUs Karpenter can provision"
  type        = string
  default     = "20"
}

variable "memory_limit" {
  description = "Maximum total memory (Gi) Karpenter can provision"
  type        = string
  default     = "40Gi"
}