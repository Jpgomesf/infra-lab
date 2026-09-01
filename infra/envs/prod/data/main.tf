terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/data"
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
  versioning                 = true
  hmac_service_account_email = module.api_identity.identity
}
