# Org bucket convention: start with the org name, end with the region (hyphens
# stripped). e.g. collectiongeek-app-test-loki-chunks-uswest1

# Shared data sources for the module. Declared ONCE here and reused everywhere
# (vpc_endpoint.tf, irsa.tf, secrets.tf) — do not redeclare in those files.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  org         = "collectiongeek"
  region_slug = replace(data.aws_region.current.name, "-", "") # us-west-1 -> uswest1
  root_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

# --- Customer Managed Keys for the chunk buckets (Trivy AWS-0132) ----------
# One CMK per bucket so a compromise of (or revocation against) one doesn't
# affect the other — same least-privilege reasoning as the separate IRSA roles.
# `bucket_key_enabled = true` on the SSE config caches a per-bucket data key,
# so KMS is hit roughly once per object batch instead of once per object —
# Loki/Tempo write rates make this the difference between cents and dollars.

data "aws_iam_policy_document" "loki_kms" {
  # Root delegation: account admins manage the key, and IAM grants on roles
  # (below) are evaluated normally.
  statement {
    sid       = "EnableRootPermissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }
  # Loki's IRSA role uses the key for S3 SSE-KMS encrypt/decrypt.
  statement {
    sid = "AllowLokiRoleUseOfTheKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.loki.arn]
    }
  }
}

resource "aws_kms_key" "loki" {
  description             = "CMK for Loki chunks S3 bucket (${var.cluster_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.loki_kms.json
}

resource "aws_kms_alias" "loki" {
  name          = "alias/observability/${var.cluster_name}-loki-chunks"
  target_key_id = aws_kms_key.loki.id
}

data "aws_iam_policy_document" "tempo_kms" {
  statement {
    sid       = "EnableRootPermissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }
  statement {
    sid = "AllowTempoRoleUseOfTheKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.tempo.arn]
    }
  }
}

resource "aws_kms_key" "tempo" {
  description             = "CMK for Tempo traces S3 bucket (${var.cluster_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.tempo_kms.json
}

resource "aws_kms_alias" "tempo" {
  name          = "alias/observability/${var.cluster_name}-tempo-traces"
  target_key_id = aws_kms_key.tempo.id
}

# --- Buckets for Loki (logs) and Tempo (traces) chunks ---------------------
# Trivy AWS-0090 (versioning) suppressed: observability chunks are ephemeral
# and lifecycle-expired (see expire rules below). Versioning would preserve
# delete-markered objects past the lifecycle window, blocking the cost cap
# without operational benefit — telemetry, not customer data.
#
# Trivy AWS-0089 (access logging) suppressed: the only write/read principals
# are the loki and tempo IRSA roles via the in-cluster service accounts.
# Account-level CloudTrail data events give equivalent forensic visibility
# without a second bucket to feed (and a third to log that one, recursively).

#trivy:ignore:AWS-0090
#trivy:ignore:AWS-0089
resource "aws_s3_bucket" "loki" {
  bucket = "${local.org}-${var.cluster_name}-loki-chunks-${local.region_slug}"
}

#trivy:ignore:AWS-0090
#trivy:ignore:AWS-0089
resource "aws_s3_bucket" "tempo" {
  bucket = "${local.org}-${var.cluster_name}-tempo-traces-${local.region_slug}"
}

# Encrypt at rest with the per-bucket CMK. bucket_key_enabled caches a
# per-bucket data key to keep KMS API costs negligible.
resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.loki.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tempo.arn
    }
    bucket_key_enabled = true
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

# Auto-expire old chunks so storage stays cheap.
# `abort_incomplete_multipart_upload` reclaims storage from multipart uploads
# that never finished (pod restart mid-write, network blip, etc.) — those
# parts aren't S3 objects, so the `expiration` rule below won't touch them.
resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {} # apply to all objects in the bucket
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration { days = var.log_retention_days }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {} # apply to all objects in the bucket
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    expiration { days = var.trace_retention_days }
  }
}
