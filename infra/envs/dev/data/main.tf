terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "dev/data"
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

  name        = "lab-dev"
  project_id  = var.project_id
  region      = var.region
  network_id  = data.terraform_remote_state.network.outputs.network_id
  tier        = "db-f1-micro"
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
