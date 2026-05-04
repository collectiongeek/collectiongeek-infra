# =============================================================================
# S3 Bucket for OpenTofu State
# =============================================================================

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of the state bucket
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: allow cross-account access from Test and Prod
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountStatAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.test_account_id}:root",
            "arn:aws:iam::${var.prod_account_id}:root"
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
      }
    ]
  })
}

# =============================================================================
# DynamoDB Table for State Locking
# =============================================================================

resource "aws_dynamodb_table" "state_lock" {
  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Allow cross-account access via resource-based policy
  # DynamoDB doesn't support resource-based policies natively,
  # so cross-account access is handled via IAM roles (see below)

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Cross-Account IAM Role for State Access
# =============================================================================

# This role can be assumed by the Test and Prod accounts to access
# the state backend (S3 + DynamoDB)

resource "aws_iam_role" "state_access" {
  name = "tofu-state-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountAssume"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.test_account_id}:root",
            "arn:aws:iam::${var.prod_account_id}:root"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "state_access" {
  name = "tofu-state-access-policy"
  role = aws_iam_role.state_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
      },
      {
        Sid    = "DynamoDBLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.state_lock.arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Route 53 Hosted Zone (will be fully configured in Phase 3)
# =============================================================================

resource "aws_route53_zone" "main" {
  name = var.domain_name
}