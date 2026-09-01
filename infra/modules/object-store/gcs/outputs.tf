output "bucket" {
  value = google_storage_bucket.this.name
}

output "s3_endpoint" {
  value = "https://storage.googleapis.com"
}

output "s3_access_key_id" {
  value     = try(google_storage_hmac_key.s3_interop[0].access_id, null)
  sensitive = true
}

output "s3_secret_access_key" {
  value     = try(google_storage_hmac_key.s3_interop[0].secret, null)
  sensitive = true
}
