terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "infra-lab-dev-6945-tofu-state"
    prefix = "dev/platform"
  }

  encryption {
    key_provider "gcp_kms" "state" {
      kms_encryption_key = "projects/infra-lab-dev-6945/locations/us-central1/keyRings/tofu/cryptoKeys/state"
      key_length         = 32
    }
    method "aes_gcm" "state" {
      keys = key_provider.gcp_kms.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method = method.aes_gcm.state
    }
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
    env        = "dev"
    managed-by = "opentofu"
  }
}

# Billing account creation and the payment method are console-only, one-time.
# Everything downstream of them is code:

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "lab-dev-monthly"

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

# Account-wide backstop across every project on the billing account. Lives in
# this stack only (not per-env) so it exists exactly once.
resource "google_billing_budget" "account" {
  billing_account = var.billing_account_id
  display_name    = "lab-account-monthly"

  amount {
    specified_amount {
      units = tostring(var.account_monthly_budget)
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
