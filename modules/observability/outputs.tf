# Consumed by Phase 2 (Loki) and Phase 3 (Tempo):
# - Role ARNs are annotated onto the loki/tempo service accounts (IRSA).
# - Bucket names are written into the Loki/Tempo Helm values so each component
#   writes chunks to its own bucket.

output "loki_role_arn" {
  description = "IAM role ARN for the loki service account (IRSA)."
  value       = aws_iam_role.loki.arn
}

output "tempo_role_arn" {
  description = "IAM role ARN for the tempo service account (IRSA)."
  value       = aws_iam_role.tempo.arn
}

output "loki_bucket_name" {
  description = "S3 bucket name for Loki chunks."
  value       = aws_s3_bucket.loki.bucket
}

output "tempo_bucket_name" {
  description = "S3 bucket name for Tempo traces."
  value       = aws_s3_bucket.tempo.bucket
}
