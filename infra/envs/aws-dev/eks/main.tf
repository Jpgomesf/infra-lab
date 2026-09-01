terraform {
  required_version = ">= 1.6"

  # GCS backend for an AWS stack — see ../network/main.tf for why.
  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "aws-dev/eks"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.11, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env        = "aws-dev"
      managed-by = "opentofu"
    }
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "aws-dev/network"
  }
}

module "cluster" {
  source = "../../../modules/cluster/eks"

  name = "lab-aws-dev"
  # Contract field. envs/dev/gke passes "${var.region}-a" because a zonal GKE
  # control plane is what the free credit covers; EKS control planes are always
  # regional and always multi-AZ, so there is no zone to choose and the module
  # ignores this. Passed anyway, because the contract call should read the same.
  location = var.region

  # Contract fields, filled exactly as the GCP envs fill them.
  network    = data.terraform_remote_state.network.outputs.network_id
  subnetwork = data.terraform_remote_state.network.outputs.subnet_id

  # AWS extra: EKS refuses a single-subnet cluster, so it gets the full list.
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  authorized_networks = var.authorized_networks

  # Same shape as envs/dev/gke: Spot only, no stable floor, in a dev env that
  # is expected to be destroyed between sessions.
  spot_machine_type = "t3a.medium"
  spot_min_nodes    = 1
  spot_max_nodes    = 3
  on_demand_nodes   = 0

  # Mirrors the dev Cloud SQL/GKE posture: this env exists to be torn down.
  deletion_protection = false
}
