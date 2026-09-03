terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/data"
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
      version = ">= 8.0, < 9.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    env        = "prod"
    managed-by = "opentofu"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "prod/network"
  }
}

module "postgres" {
  source = "../../../modules/database/cloudsql"

  name       = "lab-prod"
  project_id = var.project_id
  region     = var.region
  network_id = data.terraform_remote_state.network.outputs.network_id

  # Smallest SLA-eligible prod shape (~$114/mo). Backups + PITR stay on
  # (module defaults). Flip availability_type to REGIONAL (~2x) when
  # uptime = revenue.
  tier              = "db-custom-2-8192"
  disk_size_gb      = 50
  availability_type = "ZONAL"

  db_password = var.db_password
}

module "api_identity" {
  source = "../../../modules/iam/gke-workload-identity"

  name       = "api-identity"
  project_id = var.project_id
  namespace  = "app"
  ksa_name   = "api"
  roles      = ["roles/storage.objectUser"]
}

module "app_bucket" {
  source = "../../../modules/object-store/gcs"

  name       = "${var.project_id}-app"
  project_id = var.project_id
  location   = upper(var.region)
  versioning = true
  # 30-day undo window on top of versioning for real data.
  soft_delete_retention_seconds = 2592000
  hmac_service_account_email    = module.api_identity.identity
}

# Prod-launch DR item (own stack when prod goes live): nightly SQL exports to
# a locked-retention bucket in a SEPARATE backups project, written by a
# creator-only service account. Instance-attached backups die with the
# instance; the export pipeline is the layer that survives everything.
