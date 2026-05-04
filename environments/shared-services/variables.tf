variable "aws_profile" {
  description = "AWS CLI profile for SharedServices account"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "domain_name" {
  description = "Root domain name (e.g., example.com)"
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket name for OpenTofu state (must be globally unique)"
  type        = string
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}

variable "test_account_id" {
  description = "AWS account ID for the Test environment"
  type        = string
}

variable "prod_account_id" {
  description = "AWS account ID for the Production environment"
  type        = string
}