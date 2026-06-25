resource "random_password" "grafana" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "grafana" {
  name = "observability/grafana-admin"
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
# `observability_slack_webhook_url` into here (see "Wire the module" below).
variable "slack_webhook_url" {
  description = "Slack webhook for Grafana Alertmanager alerts (optional)."
  type        = string
  sensitive   = true
  default     = "" # empty = Slack not wired yet; the secret below isn't created
}

resource "aws_secretsmanager_secret" "slack" {
  count = var.slack_webhook_url != "" ? 1 : 0
  name  = "observability/slack-webhook"
}

resource "aws_secretsmanager_secret_version" "slack" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.slack[0].id
  secret_string = jsonencode({ url = var.slack_webhook_url })
}