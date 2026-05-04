terraform {
  backend "s3" {
    bucket         = "collectiongeek-infra-state-uswest1"
    key            = "prod/terraform.tfstate"     # Separate state from test
    region         = "us-west-1"
    dynamodb_table = "collectiongeek-infra-locks-uswest1"
    encrypt        = true

    role_arn = "arn:aws:iam::860350045682:role/tofu-state-access"
    profile  = "prod"
  }
}