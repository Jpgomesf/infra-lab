terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/platform"
  }

  # State encryption. The placeholder project is wired at prod bootstrap
  # together with the state bucket; sensitive values (DB password, HMAC
  # secret) would otherwise sit in plaintext in GCS.
  encryption {
    key_provider "gcp_kms" "state" {
      kms_encryption_key = "projects/REPLACE-prod-project/locations/us-central1/keyRings/tofu/cryptoKeys/state"
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
      version = ">= 8.0, < 9.0"
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

# The one command that beats every other protection is `gcloud projects
# delete`. A lien blocks it outright; removing the lien is a deliberate,
# audited act of its own.
resource "google_resource_manager_lien" "project" {
  parent       = "projects/${var.project_number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "infra-platform"
  reason       = "Production project - deletion blocked; remove this lien deliberately first."
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
