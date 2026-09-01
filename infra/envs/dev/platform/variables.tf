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

variable "monthly_budget_usd" {
  type    = number
  default = 100
}

variable "account_monthly_budget_usd" {
  description = "Backstop across the whole billing account, all projects."
  type        = number
  default     = 150
}
