data "aws_region" "current" {}

locals {
  org         = "collectiongeek"
  region_slug = replace(data.aws_region.current.name, "-", "") # us-west-1 -> uswest1
}

# --- Buckets for Loki (logs) and Tempo (traces) chunks ---
resource "aws_s3_bucket" "loki" {
  bucket = "${local.org}-${var.cluster_name}-loki-chunks-${local.region_slug}"
}
resource "aws_s3_bucket" "tempo" {
  bucket = "${local.org}-${var.cluster_name}-tempo-traces-${local.region_slug}"
}

# Encrypt at rest (SSE-S3). For stricter needs, switch to aws:kms.
resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# These buckets must never be public.
resource "aws_s3_bucket_public_access_block" "loki" {
  bucket                  = aws_s3_bucket.loki.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "tempo" {
  bucket                  = aws_s3_bucket.tempo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Auto-expire old chunks so storage stays cheap (your retention policy, as code).
resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {} # apply to all objects in the bucket
    expiration { days = var.log_retention_days }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {} # apply to all objects in the bucket
    expiration { days = var.trace_retention_days }
  }
}