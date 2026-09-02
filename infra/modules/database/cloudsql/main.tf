resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.postgres_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.availability_type
    activation_policy = var.activation_policy

    # Server-side twin of the provider-level deletion_protection above: that
    # one only stops `tofu destroy`; this one makes the API itself refuse
    # deletion from any path, console included.
    deletion_protection_enabled = var.deletion_protection
    disk_size                   = var.disk_size_gb
    disk_type                   = "PD_SSD"
    disk_autoresize             = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = var.backups_enabled
      point_in_time_recovery_enabled = var.backups_enabled
      # PITR window; billed as instance disk, separate from backup retention.
      transaction_log_retention_days = var.backups_enabled ? var.transaction_log_retention_days : null

      dynamic "backup_retention_settings" {
        for_each = var.backups_enabled ? [1] : []
        content {
          retained_backups = var.retained_backups
          retention_unit   = "COUNT"
        }
      }
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.database_name
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "app" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = var.db_password
}
