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
