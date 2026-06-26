# --- Customer Managed Key for Secrets Manager entries (Trivy AWS-0098) ----
# A single CMK for all observability/* secrets. ESO reads them via a
# `kms:ViaService = secretsmanager.<region>.amazonaws.com` condition on its
# own IAM policy (see modules/cluster-addons/main.tf), so the key policy here
# only needs the root-delegation statement — IAM grants handle the rest.

data "aws_iam_policy_document" "secrets_kms" {
  statement {
    sid       = "EnableRootPermissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.root_arn]
    }
  }
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for observability/* Secrets Manager entries (${var.cluster_name})"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.secrets_kms.json
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/observability/${var.cluster_name}-secrets"
  target_key_id = aws_kms_key.secrets.id
}

# --- Grafana admin password: GENERATED, never supplied by a human -----------
# KNOWN LIMITATION (tracked for a follow-up PR):
# `random_password.result` and `aws_secretsmanager_secret_version.secret_string`
# are stored in Terraform state in plaintext — `sensitive = true` only affects
# CLI display, not state. The mitigations today are layered KMS encryption on
# the state bucket itself and the tightly-scoped IAM access to it (see §0.5 of
# PHASE-0-FOUNDATIONS). The proper fix is `ephemeral "random_password"` +
# `secret_string_wo` write-only attribute, which requires OpenTofu ≥ 1.11,
# random ≥ 3.7, and aws ≥ 5.83 — small refactor, but it rotates the password,
# so it earns its own focused PR with a reviewed plan rather than a drive-by.
resource "random_password" "grafana" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "grafana" {
  name       = "observability/grafana-admin"
  kms_key_id = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana.result
  })
}

# --- Alertmanager Slack webhook: OPTIONAL, and DISTINCT from the Argo CD webhook ---
# This is the module's local input. The ROOT passes its
# `observability_slack_webhook_url` into here.
variable "slack_webhook_url" {
  description = "Slack webhook for Grafana Alertmanager alerts (optional)."
  type        = string
  sensitive   = true
  default     = "" # empty = Slack not wired yet; the secret below isn't created
}

locals {
  # Declassify ONLY the enable predicate — Terraform rejects sensitive values
  # as `count` arguments. The URL itself stays sensitive everywhere it's
  # actually used (secret_string below, CLI/plan output). The boolean leaks
  # "is Slack wired up: yes/no", which isn't secret. The empty-default path
  # happens to evaluate statically and slip past the guard today, but the
  # moment a real webhook is passed in, count derives from a sensitive value
  # and apply errors — this declassification is what keeps that working.
  slack_enabled = nonsensitive(var.slack_webhook_url != "")
}

resource "aws_secretsmanager_secret" "slack" {
  count      = local.slack_enabled ? 1 : 0
  name       = "observability/slack-webhook"
  kms_key_id = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "slack" {
  count         = local.slack_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.slack[0].id
  secret_string = jsonencode({ url = var.slack_webhook_url })
}
