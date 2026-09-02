terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/gke"
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

module "cluster" {
  source = "../../../modules/cluster/gke"

  name       = "lab-prod"
  project_id = var.project_id
  # Zonal to start. When uptime = revenue, switch to var.region for a regional
  # control plane (SLA 99.5% -> 99.95%; forfeits the zonal free-tier credit,
  # which the dev cluster is already consuming anyway).
  location   = "${var.region}-a"
  network    = data.terraform_remote_state.network.outputs.network_id
  subnetwork = data.terraform_remote_state.network.outputs.subnet_id

  authorized_networks = var.authorized_networks

  spot_machine_type = "e2-medium"
  spot_min_nodes    = 1
  spot_max_nodes    = 3
  # Stable floor for critical pods (Spot preemption gives ~30s best-effort).
  on_demand_nodes        = 1
  on_demand_machine_type = "e2-small"
}
