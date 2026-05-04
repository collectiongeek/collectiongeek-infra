variable "aws_profile" {
  description = "AWS CLI profile for the Test account"
  type        = string
  default     = "test"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}