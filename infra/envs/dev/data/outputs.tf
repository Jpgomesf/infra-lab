output "postgres_private_ip" {
  value = module.postgres.private_ip
}

output "bucket" {
  value = module.app_bucket.bucket
}

output "s3_endpoint" {
  value = module.app_bucket.s3_endpoint
}

output "s3_access_key_id" {
  value     = module.app_bucket.s3_access_key_id
  sensitive = true
}

output "s3_secret_access_key" {
  value     = module.app_bucket.s3_secret_access_key
  sensitive = true
}

output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}
