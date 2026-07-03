# GitHub Actions OIDC provider for this AWS account.
#
# One provider per account, used by any repo that wants to federate from
# GitHub. If the account already has this provider (e.g. created earlier by
# CLI or by another stack), import it before the first apply:
#
#   tofu import module.github_oidc.aws_iam_openid_connect_provider.github \
#     arn:aws:iam::<this-account-id>:oidc-provider/token.actions.githubusercontent.com
#
# The thumbprint is the well-known one for GitHub's OIDC endpoint; AWS
# doesn't validate it post-registration for token.actions.githubusercontent.com,
# but the field is required.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Role that GitHub Actions runs in this account assume via OIDC.
#
# The trust policy ties the role to a *specific repo* and a *specific set
# of GitHub Environments*. Without the `:environment:<name>` segment, any
# workflow in the repo (including a contributor's branch) could assume
# this role. Scoping to the Environment(s) makes each GitHub Environment's
# protection rules — required reviewers, branch restrictions — the gate
# for who can take this identity. Same shape as IRSA's `:sub` condition,
# pointed at GitHub instead of EKS.
#
# `sub` is matched against a list, so the role can be shared by more than
# one Environment (e.g. an ungated plan Environment and a gated apply
# Environment) — StringLike treats the list as OR: any pattern may match.
resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for env in var.github_environment_names :
              "repo:${var.github_org}/${var.github_repo}:environment:${env}"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
