# Region comes from data.aws_region.current, declared once in s3.tf — do NOT
# redeclare it here, or Terraform errors on a duplicate data source.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids   # the private subnets' route tables
}