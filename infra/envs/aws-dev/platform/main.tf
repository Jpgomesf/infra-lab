terraform {
  required_version = ">= 1.6"

  # GCS backend for an AWS stack — see ../network/main.tf for why.
  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "aws-dev/platform"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.11, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env        = "aws-dev"
      managed-by = "opentofu"
    }
  }
}

# Account creation, the root user, and the payment method are console-only and
# one-time — the same "console, once" layer as GCP's billing account. Everything
# downstream of them is code, starting here.
#
# The GCP equivalent (google_billing_budget) filters by project, which gives
# real isolation. AWS Budgets are account-scoped, and this lab has one account,
# so this budget covers the AWS side entirely. If aws-dev and a future aws-prod
# ever share an account, split them with a cost_filter on the `env` tag that the
# provider's default_tags already stamp on every resource.

resource "aws_budgets_budget" "monthly" {
  name         = "lab-aws-dev-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Forecast alerts fire before the money is spent, which is the only kind that
  # helps when an EKS control plane bills by the hour whether or not it is used.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
