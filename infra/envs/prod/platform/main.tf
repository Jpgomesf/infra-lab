terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/platform"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # The billingbudgets API requires a quota project on every request; with
  # user ADC that only happens when these two are set.
  user_project_override = true
  billing_project       = var.project_id

  default_labels = {
    env        = "prod"
    managed-by = "opentofu"
  }
}

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "lab-prod-monthly"

  budget_filter {
    projects = ["projects/${var.project_number}"]
  }

  amount {
    specified_amount {
      units = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  threshold_rules {
    threshold_percent = 1.0
  }
}
