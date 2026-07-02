terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Floor is 5.83: modules/observability/secrets.tf uses the
      # `secret_string_wo` write-only attribute (added in aws 5.83) to keep
      # secret payloads out of Terraform state.
      version = "~> 5.83"
    }
    helm = {
      source = "hashicorp/helm"
      # Pinned to 3.0.x (Helm SDK 3.17.2). Provider 3.1.x bundles Helm 3.18.5,
      # which has a regression rejecting remote $ref URLs in chart
      # values.schema.json (helm/helm#31136) — breaks the F5 nginx-ingress
      # chart. Revert to ~> 3.0 once a provider bundles Helm >= 3.18.6/3.19.
      version = ">= 3.0.0, < 3.1.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source = "hashicorp/random"
      # Floor is 3.7: modules/observability/secrets.tf uses the
      # `ephemeral "random_password"` block (added in random 3.7) so the
      # generated Grafana password never lands in state.
      version = "~> 3.7"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # In CI: var.aws_profile is "" → null → provider uses env-var creds set by
  # aws-actions/configure-aws-credentials (OIDC). On a laptop: pass --profile.
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      ManagedBy   = "opentofu"
      Environment = "test"
      Project     = "infrastructure"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", var.cluster_name],
        var.aws_profile != "" ? ["--profile", var.aws_profile] : []
      )
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", var.cluster_name],
      var.aws_profile != "" ? ["--profile", var.aws_profile] : []
    )
  }
}