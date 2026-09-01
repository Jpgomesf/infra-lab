# Same output names as infra/envs/dev/data.
output "postgres_private_ip" {
  description = "On RDS this is a private DNS name, not an address — see the rds module's outputs."
  value       = module.postgres.private_ip
}

output "bucket" {
  value = module.app_bucket.bucket
}

# Null on AWS: the S3 SDK resolves its own regional endpoint, so the app leaves
# S3_ENDPOINT unset. On GCP this carries https://storage.googleapis.com.
output "s3_endpoint" {
  value = module.app_bucket.s3_endpoint
}

output "api_identity" {
  description = "IAM role ARN bound to the app/api ServiceAccount."
  value       = module.api_identity.identity
}
