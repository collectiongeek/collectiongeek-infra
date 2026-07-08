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
# The password is produced by an EPHEMERAL resource and written through the
# `secret_string_wo` write-only attribute, so neither the generated value nor
# the assembled secret payload is ever persisted to Terraform state (see
# https://opentofu.org/docs/language/resources/ephemeral/). `ephemeral.*.result`
# lives only for the duration of a single plan/apply graph walk. Requires
# OpenTofu >= 1.11, random >= 3.7, aws >= 5.83 (pinned in each environment's
# providers.tf).
#
# Because write-only values are never stored, the provider cannot diff them:
# bump `secret_string_wo_version` to force a rewrite, i.e. to ROTATE the
# password on a subsequent apply.
ephemeral "random_password" "grafana" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "grafana" {
  name       = "observability/grafana-admin"
  kms_key_id = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string_wo = jsonencode({
    admin-user     = "admin"
    admin-password = ephemeral.random_password.grafana.result
  })
  secret_string_wo_version = 1
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
  count                    = local.slack_enabled ? 1 : 0
  secret_id                = aws_secretsmanager_secret.slack[0].id
  secret_string_wo         = jsonencode({ url = var.slack_webhook_url })
  secret_string_wo_version = 1
}

# --- Portal SSO OIDC client secrets: OPTIONAL (Portal SSO doc §S.3) ---------
# One WorkOS OAuth-app client secret per portal. Same shape as the Slack
# webhook above: empty default = not created; write-only = never in state.
# Named under observability/* because that prefix is ESO's read scope. The
# Grafana key name is the exact GF_* env var so the ExternalSecret can sync
# it verbatim into the pod environment.

variable "grafana_oidc_client_secret" {
  description = "WorkOS OAuth-app client secret for Grafana SSO (optional)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_oidc_client_secret" {
  description = "WorkOS OAuth-app client secret for Argo CD SSO (optional)."
  type        = string
  sensitive   = true
  default     = ""
}

locals {
  # Same declassification story as slack_enabled above.
  grafana_oidc_enabled = nonsensitive(var.grafana_oidc_client_secret != "")
  argocd_oidc_enabled  = nonsensitive(var.argocd_oidc_client_secret != "")
}

resource "aws_secretsmanager_secret" "grafana_oidc" {
  count      = local.grafana_oidc_enabled ? 1 : 0
  name       = "observability/grafana-oidc"
  kms_key_id = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "grafana_oidc" {
  count                    = local.grafana_oidc_enabled ? 1 : 0
  secret_id                = aws_secretsmanager_secret.grafana_oidc[0].id
  secret_string_wo         = jsonencode({ GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = var.grafana_oidc_client_secret })
  secret_string_wo_version = 1
}

resource "aws_secretsmanager_secret" "argocd_oidc" {
  count      = local.argocd_oidc_enabled ? 1 : 0
  name       = "observability/argocd-oidc"
  kms_key_id = aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret_version" "argocd_oidc" {
  count                    = local.argocd_oidc_enabled ? 1 : 0
  secret_id                = aws_secretsmanager_secret.argocd_oidc[0].id
  secret_string_wo         = jsonencode({ client-secret = var.argocd_oidc_client_secret })
  secret_string_wo_version = 1
}
