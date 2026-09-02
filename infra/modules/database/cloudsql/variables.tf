variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  type = string
}

variable "postgres_version" {
  type    = string
  default = "POSTGRES_16"
}

variable "tier" {
  description = "db-f1-micro (~$10/mo, no SLA, dev only) | db-custom-2-8192 (~$114/mo, prod floor)."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL, or REGIONAL for HA (~2x compute+storage)."
  type        = string
  default     = "ZONAL"
}

variable "disk_size_gb" {
  type    = number
  default = 10
}

variable "backups_enabled" {
  type    = bool
  default = true
}

variable "transaction_log_retention_days" {
  description = "PITR window (1-7 on Enterprise edition)."
  type        = number
  default     = 7
}

variable "retained_backups" {
  description = "Rolling count of automated backups kept. Instance-attached backups die with the instance — off-instance exports to a locked bucket are the real DR layer (prod-launch item)."
  type        = number
  default     = 14
}

variable "activation_policy" {
  description = "ALWAYS runs the instance; NEVER stops it (compute unbilled, storage kept) — the dev cost lever."
  type        = string
  default     = "ALWAYS"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "database_name" {
  type    = string
  default = "app"
}

variable "db_user" {
  type    = string
  default = "app"
}

variable "db_password" {
  description = "Feed from Secret Manager / CI secret, never a committed tfvars file."
  type        = string
  sensitive   = true
}
