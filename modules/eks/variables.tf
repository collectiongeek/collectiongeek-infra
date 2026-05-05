variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (for load balancers)"
  type        = list(string)
}

variable "system_node_instance_types" {
  description = "Instance types for the system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_node_desired_size" {
  description = "Desired number of system nodes"
  type        = number
  default     = 1
}

variable "system_node_min_size" {
  description = "Minimum number of system nodes"
  type        = number
  default     = 1
}

variable "system_node_max_size" {
  description = "Maximum number of system nodes"
  type        = number
  default     = 2
}