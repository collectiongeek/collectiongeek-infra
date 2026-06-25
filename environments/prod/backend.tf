# Partial backend config — see environments/test/backend.tf for the rationale.
terraform {
  backend "s3" {
    encrypt = true
  }
}
