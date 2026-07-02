# =============================================================================
# S3 Gateway VPC Endpoint
# =============================================================================
# VPC-level shared infrastructure: keeps in-account S3 traffic (Loki/Tempo
# chunks, ALB logs, app uploads, audit archives, ...) on the AWS backbone via
# the private route tables instead of egressing through the NAT Gateway —
# cheaper and lower-latency for any current or future in-account S3 consumer.
#
# Toggle with var.enable_s3_endpoint (default true) so the module stays generic.

# Region and account ID for the service name and the endpoint policy.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Endpoint policy: restrict to in-account S3 only. Because this endpoint is
# shared VPC infrastructure (not tied to any one bucket), we can't scope it to
# specific bucket ARNs without breaking other in-account S3 use cases. The
# in-account restriction raises the cost of exfiltration to attacker-owned
# buckets — that path is forced onto NAT (more expensive, more visible in flow
# logs) — without constraining legitimate traffic.
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
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id # the private subnets' route tables
  policy            = data.aws_iam_policy_document.s3_endpoint.json
}
