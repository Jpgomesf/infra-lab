output "postgres_private_ip" {
  value = module.postgres.private_ip
}

output "bucket" {
  value = module.app_bucket.bucket
}

output "s3_endpoint" {
  value = module.app_bucket.s3_endpoint
}
