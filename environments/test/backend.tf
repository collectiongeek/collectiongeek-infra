terraform {
  backend "s3" {
    bucket         = "collectiongeek-infra-state-uswest1"         # Same bucket as shared-services
    key            = "test/terraform.tfstate"                     # Different key (path) per environment
    region         = "us-west-1"
    dynamodb_table = "collectiongeek-infra-locks-uswest1"
    encrypt        = true

    # Cross-account access: assume the role in SharedServices
    role_arn = "arn:aws:iam::860350045682:role/tofu-state-access"  # SharedServices account ID
    profile  = "test"
  }
}