terraform {
  required_version = ">= 1.6"

  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "prod/gke"
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

# Dedicated node identity. The default compute SA carries roles/editor; Workload
# Identity protects the pod path only, so the node path gets its own minimal SA.
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "lab-prod-nodes"
  display_name = "GKE nodes (prod)"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
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

  node_service_account = google_service_account.nodes.email

  spot_machine_type = "e2-medium"
  spot_min_nodes    = 1
  spot_max_nodes    = 3
  # Stable floor for critical pods (Spot preemption gives ~30s best-effort).
  on_demand_nodes        = 1
  on_demand_machine_type = "e2-small"
}
