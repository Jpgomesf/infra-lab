resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  versioning {
    enabled = var.versioning
  }

  # Soft-deleted objects keep billing until the window expires; churny buckets
  # (CI artifacts, scratch) should set this to 0.
  dynamic "soft_delete_policy" {
    for_each = var.soft_delete_retention_seconds != null ? [1] : []
    content {
      retention_duration_seconds = var.soft_delete_retention_seconds
    }
  }
}

resource "google_storage_hmac_key" "s3_interop" {
  count = var.hmac_service_account_email != null ? 1 : 0

  project               = var.project_id
  service_account_email = var.hmac_service_account_email
}
