# Trust policy: allow the k8s service account "observability:loki" to assume this role
data "aws_iam_policy_document" "loki_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:loki"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "loki" {
  name               = "${var.cluster_name}-loki"
  assume_role_policy = data.aws_iam_policy_document.loki_trust.json
}
# Permission policy: only this bucket, only these actions
data "aws_iam_policy_document" "loki_s3" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [aws_s3_bucket.loki.arn, "${aws_s3_bucket.loki.arn}/*"]
  }
}
resource "aws_iam_role_policy" "loki" {
  role   = aws_iam_role.loki.id
  policy = data.aws_iam_policy_document.loki_s3.json
}

# ---- Same three resources again for Tempo (service account "observability:tempo") ----
data "aws_iam_policy_document" "tempo_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:tempo"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "tempo" {
  name               = "${var.cluster_name}-tempo"
  assume_role_policy = data.aws_iam_policy_document.tempo_trust.json
}
data "aws_iam_policy_document" "tempo_s3" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [aws_s3_bucket.tempo.arn, "${aws_s3_bucket.tempo.arn}/*"]
  }
}
resource "aws_iam_role_policy" "tempo" {
  role   = aws_iam_role.tempo.id
  policy = data.aws_iam_policy_document.tempo_s3.json
}