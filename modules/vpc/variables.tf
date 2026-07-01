variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name (used for subnet tagging)"
  type        = string
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost savings for non-prod)"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch"
  type        = bool
  default     = true
}

variable "flow_logs_traffic_type" {
  description = "Traffic to capture in flow logs. REJECT keeps volume/cost low while retaining security-relevant events."
  type        = string
  default     = "REJECT"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be one of ACCEPT, REJECT, or ALL."
  }
}

variable "flow_logs_retention_days" {
  description = "Retention (days) for VPC flow logs; bounds CloudWatch cost"
  type        = number
  default     = 14
}
