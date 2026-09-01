terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "dev/gke"
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

module "cluster" {
  source = "../../../modules/cluster/gke"

  name       = "lab-dev"
  project_id = var.project_id
  # Zonal: the $74.40/mo GKE credit covers one zonal cluster's fee; regional is not covered.
  location   = "${var.region}-a"
  network    = data.terraform_remote_state.network.outputs.network_id
  subnetwork = data.terraform_remote_state.network.outputs.subnet_id

  authorized_networks = var.authorized_networks

  spot_machine_type = "e2-medium"
  spot_min_nodes    = 1
  spot_max_nodes    = 3
  on_demand_nodes   = 0
}
