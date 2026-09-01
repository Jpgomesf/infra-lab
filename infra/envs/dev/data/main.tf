terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "infra-lab-dev-6945-tofu-state"
    prefix = "dev/data"
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
    # terraform_remote_state reads need their own decryption config — the
    # root state/plan blocks do not cover data sources.
    remote_state_data_sources {
      default {
        method = method.aes_gcm.state
      }
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "< 8.2"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    env        = "dev"
    managed-by = "opentofu"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "dev/network"
  }
}

module "postgres" {
  source = "../../../modules/database/cloudsql"

  name       = "lab-dev"
  project_id = var.project_id
  region     = var.region
  network_id = data.terraform_remote_state.network.outputs.network_id
  tier       = "db-f1-micro"

  # The dev DB is disposable: rebuilt from migrations + idempotent seeds, so
  # no backups/PITR, no deletion protection, and stoppable when idle
  # (db_activation_policy = "NEVER" halts compute billing, keeps storage).
  backups_enabled     = false
  deletion_protection = false
  activation_policy   = var.db_activation_policy

  db_password = var.db_password
}

# Cloud identity for the API workload; the KSA side lives in k8s/base.
module "api_identity" {
  source = "../../../modules/iam/gke-workload-identity"

  name       = "api"
  project_id = var.project_id
  namespace  = "app"
  ksa_name   = "api"
  roles      = ["roles/storage.objectUser"]
}

module "app_bucket" {
  source = "../../../modules/object-store/gcs"

  name                       = "${var.project_id}-app"
  project_id                 = var.project_id
  location                   = upper(var.region)
  hmac_service_account_email = module.api_identity.identity
}
