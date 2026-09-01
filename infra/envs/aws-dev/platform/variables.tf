variable "region" {
  type    = string
  default = "us-east-1"
}

variable "monthly_budget_usd" {
  description = "Matches envs/dev. An EKS control plane (~$73/mo) plus a NAT gateway (~$33/mo) already consumes most of it before a workload exists."
  type        = number
  default     = 100
}

variable "budget_notification_email" {
  description = <<-EOT
    Where budget alerts go. AWS Budgets has no equivalent of GCP's default
    billing-admin recipients: a notification with no subscriber is rejected, so
    this has no default and must be supplied (TF_VAR_budget_notification_email).
  EOT
  type        = string
}
