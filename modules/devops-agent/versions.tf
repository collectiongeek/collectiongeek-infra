terraform {
  # Hard floors this module actually depends on:
  #   awscc >= 1.94 — first provider release validated with the
  #                   devopsagent_agent_space / devopsagent_association
  #                   resources this module is built on (service GA'd 2026).
  #   time  >= 0.13 — time_sleep, used to ride out IAM propagation (main.tf).
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
    # DevOps Agent has no resources in the classic `aws` provider; AWS ships
    # them through the Cloud Control (awscc) provider instead. The caller must
    # configure this provider in a *supported* DevOps Agent region (us-west-2
    # for us) — the classic provider stays on us-west-1. Two providers, two
    # regions, one account.
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.94"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13"
    }
  }
}
