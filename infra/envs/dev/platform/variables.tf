variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "billing_account_id" {
  type = string
}

variable "monthly_budget" {
  description = "Units of the billing account's own currency (no currency is hardcoded)."
  type        = number
  default     = 100
}

variable "account_monthly_budget" {
  description = "Backstop across the whole billing account, all projects. Same currency rule."
  type        = number
  default     = 150
}
