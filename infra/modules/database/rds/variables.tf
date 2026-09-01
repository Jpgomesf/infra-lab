variable "name" {
  type = string
}

variable "project_id" {
  description = "Contract input. Accepted and unused — AWS has no project."
  type        = string
  default     = null
}

variable "region" {
  description = "Contract input. Accepted for parity; placement comes from the provider block and the subnet group."
  type        = string
  default     = null
}

variable "network_id" {
  description = "Contract input: the VPC id from the network capability. Used for the instance's security group."
  type        = string
}

variable "subnet_ids" {
  description = "Provider-specific extra. Private subnet ids for the DB subnet group — the AWS answer to GCP's Private Service Access peering."
  type        = list(string)
}

variable "tier" {
  description = <<-EOT
    Contract input -> `instance_class`.
    db.t4g.micro (~$12/mo on-demand) is the cheapest viable Postgres shape and
    the one the legacy 12-month free tier covers. db.m7g.large is the prod floor.
  EOT
  type        = string
  default     = "db.t4g.micro"
}

variable "availability_type" {
  description = "Contract input. ZONAL -> single-AZ; REGIONAL -> multi_az = true (~2x cost, standby in a second AZ)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL (the contract's vocabulary)."
  }
}

variable "postgres_version" {
  description = "Major version only; RDS picks and auto-upgrades the minor. 18 is the newest GA major on RDS as of 2026-09."
  type        = string
  default     = "18"
}

variable "disk_size_gb" {
  description = "Initial gp3 allocation. RDS gp3 has a 20 GiB minimum; the legacy free tier covers 20 GiB."
  type        = number
  default     = 20
}

variable "max_disk_size_gb" {
  description = "Storage autoscaling ceiling. null disables autoscaling."
  type        = number
  default     = 100
}

variable "backups_enabled" {
  description = "Contract-level knob, same name as the Cloud SQL module. false also flips skip_final_snapshot on — a disposable DB is disposable all the way down."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Automated-backup retention when backups_enabled. RDS point-in-time recovery is implied by any non-zero retention."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Contract input. Must default to true."
  type        = bool
  default     = true
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
  description = "Feed from Secrets Manager / CI secret, never a committed tfvars file."
  type        = string
  sensitive   = true
}

variable "allowed_cidr_blocks" {
  description = "Provider-specific extra. CIDRs allowed to reach 5432. Normally just the VPC range."
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Provider-specific extra. Security groups allowed to reach 5432 — e.g. the EKS cluster security group."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "Customer-managed key for storage encryption. null uses the AWS-managed aws/rds key, which is free and still satisfies encryption-at-rest."
  type        = string
  default     = null
}
