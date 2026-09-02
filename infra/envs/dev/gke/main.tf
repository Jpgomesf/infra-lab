terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "infra-lab-dev-6945-tofu-state"
    prefix = "dev/gke"
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
      version = ">= 8.0, < 9.0"
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

module "cluster" {
  source = "../../../modules/cluster/gke"

  name       = "lab-dev"
  project_id = var.project_id
  # Zonal: the $74.40/mo GKE credit covers one zonal cluster's fee; regional is not covered.
  location   = "${var.region}-a"
  network    = data.terraform_remote_state.network.outputs.network_id
  subnetwork = data.terraform_remote_state.network.outputs.subnet_id

  authorized_networks = var.authorized_networks
  # Flip to false (then apply) as the deliberate first step of a destroy.
  deletion_protection = var.cluster_deletion_protection

  spot_machine_type = "e2-medium"
  spot_min_nodes    = 1
  spot_max_nodes    = 3
  on_demand_nodes   = 0
}
