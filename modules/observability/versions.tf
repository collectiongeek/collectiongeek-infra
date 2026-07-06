terraform {
  # Hard floors this module actually depends on (see secrets.tf):
  #   OpenTofu >= 1.11 — ephemeral resources + write-only attributes
  #   aws >= 5.83      — secret_string_wo / secret_string_wo_version
  #   random >= 3.7    — ephemeral random_password
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7"
    }
  }
}
