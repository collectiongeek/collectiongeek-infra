# Region and account ID come from data sources declared once in s3.tf — do NOT
# redeclare them here, or Terraform errors on a duplicate data source.

# Endpoint policy: restrict to in-account S3 only. The endpoint is shared VPC
# infrastructure (not observability-specific), so we *can't* tie it to the
# loki/tempo bucket ARNs without breaking any other in-account S3 use case
# present or future (ALB logs, app uploads, audit archives, etc.). The
# in-account restriction raises the cost of exfiltration to attacker-owned
# buckets — that path is forced onto NAT (more expensive, more visible in
# flow logs) — without constraining legitimate traffic.
#
# NOTE: this endpoint really belongs in the VPC module, not observability —
# it's here because §0.4 of the foundations guide creates it during the
# observability bootstrap if one didn't already exist. Treat moving it as
# a future architectural cleanup; see PR backlog.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid = "AllowInAccountS3"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids # the private subnets' route tables
  policy            = data.aws_iam_policy_document.s3_endpoint.json
}