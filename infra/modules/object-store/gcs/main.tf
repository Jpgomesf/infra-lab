resource "google_storage_bucket" "this" {
  name                        = var.name
  project                     = var.project_id
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  versioning {
    enabled = var.versioning
  }

  # WORM for backup-role buckets: while an object is younger than the window,
  # no identity can delete or overwrite it. retention_locked = true makes the
  # policy itself irreversible — the "backups nobody can delete" setting.
  dynamic "retention_policy" {
    for_each = var.retention_period_seconds != null ? [1] : []
    content {
      retention_period = var.retention_period_seconds
      is_locked        = var.retention_locked
    }
  }

  lifecycle {
    # GCS forbids combining versioning with a retention policy. The choice is
    # by bucket ROLE: mutable app data = versioning; immutable backups =
    # retention. Never both.
    precondition {
      condition     = !(var.versioning && var.retention_period_seconds != null)
      error_message = "versioning and retention_period_seconds are mutually exclusive — pick by bucket role."
    }
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
