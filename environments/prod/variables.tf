variable "aws_profile" {
  description = "AWS CLI profile for the Production account"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}