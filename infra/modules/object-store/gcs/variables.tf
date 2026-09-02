variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "location" {
  description = "Keep in the cluster's region: same-location traffic is free."
  type        = string
  default     = "US-CENTRAL1"
}

variable "versioning" {
  type    = bool
  default = false
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "hmac_service_account_email" {
  type    = string
  default = null
}

variable "retention_period_seconds" {
  description = "WORM window for backup-role buckets. Mutually exclusive with versioning."
  type        = number
  default     = null
}

variable "retention_locked" {
  description = "Locks the retention policy irreversibly (Bucket Lock). One-way door — only for real backup buckets."
  type        = bool
  default     = false
}

variable "soft_delete_retention_seconds" {
  description = "null = GCP default (7 days). 0 disables soft delete for churny buckets."
  type        = number
  default     = null
}
