terraform {
  backend "s3" {
    bucket         = "collectiongeek-infra-state-uswest1"       # Replace with your actual bucket name
    key            = "shared-services/terraform.tfstate"
    region         = "us-west-1"
    profile        = "shared-services"
    dynamodb_table = "collectiongeek-infra-locks-uswest1"        # Replace with your actual table name
    encrypt        = true
  }
}