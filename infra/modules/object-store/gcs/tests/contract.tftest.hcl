# Contract tests: plan-time assertions with a mocked provider — no cloud, no
# credentials. `tofu test` from the module directory.

mock_provider "google" {}

variables {
  name       = "example-bucket"
  project_id = "example-project"
}

run "invariants_hold_by_default" {
  command = plan

  assert {
    condition     = google_storage_bucket.this.uniform_bucket_level_access == true
    error_message = "uniform bucket-level access is a contract invariant, never optional"
  }

  assert {
    condition     = google_storage_bucket.this.public_access_prevention == "enforced"
    error_message = "public access prevention is a contract invariant, never optional"
  }

  assert {
    condition     = google_storage_bucket.this.force_destroy == false
    error_message = "buckets must not default to force_destroy"
  }

  assert {
    condition     = length(google_storage_hmac_key.s3_interop) == 0
    error_message = "no HMAC key may be minted unless a service account is passed"
  }
}

run "hmac_key_follows_service_account" {
  command = plan

  variables {
    hmac_service_account_email = "svc@example-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_storage_hmac_key.s3_interop) == 1
    error_message = "passing a service account must mint exactly one HMAC key"
  }
}

run "retention_renders_for_backup_buckets" {
  command = plan

  variables {
    retention_period_seconds = 2592000
  }

  assert {
    # The provider types retention_period as a string.
    condition     = google_storage_bucket.this.retention_policy[0].retention_period == "2592000"
    error_message = "retention_period_seconds must render a retention policy"
  }

  assert {
    condition     = google_storage_bucket.this.retention_policy[0].is_locked == false
    error_message = "the lock must never be implicit — retention_locked is opt-in"
  }
}

run "versioning_and_retention_are_mutually_exclusive" {
  command = plan

  variables {
    versioning               = true
    retention_period_seconds = 2592000
  }

  expect_failures = [google_storage_bucket.this]
}

run "soft_delete_can_be_disabled_for_churny_buckets" {
  command = plan

  variables {
    soft_delete_retention_seconds = 0
  }

  assert {
    condition     = google_storage_bucket.this.soft_delete_policy[0].retention_duration_seconds == 0
    error_message = "soft_delete_retention_seconds = 0 must render a disabling policy"
  }
}
