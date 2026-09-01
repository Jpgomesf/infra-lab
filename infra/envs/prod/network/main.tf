terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/network"
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

module "vpc" {
  source = "../../../modules/network/gcp-vpc"

  name       = "lab-prod"
  project_id = var.project_id
  region     = var.region
  # Distinct from dev's 10.10/10.20/10.30 ranges so the VPCs could be peered
  # later without overlap.
  subnet_cidr   = "10.40.0.0/20"
  pods_cidr     = "10.50.0.0/16"
  services_cidr = "10.60.0.0/20"
}
