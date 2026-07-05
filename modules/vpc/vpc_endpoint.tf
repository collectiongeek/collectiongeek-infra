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

  # ECR stores image layers in an AWS-owned regional S3 bucket and redirects
  # pulls there via presigned URLs. A Gateway endpoint captures ALL regional
  # S3 traffic (prefix-list route, no NAT fallback), so without this exception
  # the in-account restriction above 403s every layer download and nodes
  # can't pull images (EKS addons, aws-node, kube-proxy, app images).
  # https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html#ecr-minimum-s3-perms
  statement {
    sid = "AllowEcrLayerBucket"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*"]
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
