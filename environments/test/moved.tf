# Relocation of the S3 Gateway VPC endpoint from the observability module to the
# VPC module (it's VPC-level shared infra, not observability-specific). This
# records the state move so `tofu apply` refactors it in place instead of
# destroying and recreating the endpoint. Safe to delete once both test and prod
# have applied it.
moved {
  from = module.observability.aws_vpc_endpoint.s3
  to   = module.vpc.aws_vpc_endpoint.s3[0]
}
