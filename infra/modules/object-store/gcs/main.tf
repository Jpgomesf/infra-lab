resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  versioning {
    enabled = var.versioning
  }
}

resource "google_storage_hmac_key" "s3_interop" {
  count = var.hmac_service_account_email != null ? 1 : 0

  project               = var.project_id
  service_account_email = var.hmac_service_account_email
}
