# Contract tests: plan-time assertions with a mocked provider — no cloud, no
# credentials. These pin the creation-time decisions that cannot be retrofitted
# without recreating the cluster.

mock_provider "google" {}

variables {
  name                 = "example"
  project_id           = "example-project"
  location             = "us-central1-a"
  network              = "projects/example-project/global/networks/example"
  subnetwork           = "projects/example-project/regions/us-central1/subnetworks/example"
  node_service_account = "example-nodes@example-project.iam.gserviceaccount.com"
}

run "creation_time_invariants" {
  command = plan

  assert {
    condition     = google_container_cluster.this.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Dataplane V2 is required or NetworkPolicy objects are silently ignored"
  }

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_endpoint == true
    error_message = "the control plane must not expose a public IP endpoint"
  }

  assert {
    condition     = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].allow_external_traffic == true
    error_message = "the IAM-authenticated DNS endpoint is the only external path to the control plane"
  }

  assert {
    condition     = google_container_cluster.this.enable_shielded_nodes == true
    error_message = "shielded nodes are a contract invariant"
  }

  assert {
    condition     = google_container_cluster.this.deletion_protection == true
    error_message = "deletion_protection must default to true"
  }
}

run "node_pools_use_dedicated_identity_and_secure_boot" {
  command = plan

  variables {
    on_demand_nodes = 1
  }

  assert {
    condition     = google_container_node_pool.spot.node_config[0].service_account == var.node_service_account
    error_message = "the spot pool must run as the dedicated node SA"
  }

  assert {
    condition     = google_container_node_pool.on_demand[0].node_config[0].service_account == var.node_service_account
    error_message = "the on-demand pool must run as the dedicated node SA"
  }

  assert {
    condition     = google_container_node_pool.spot.node_config[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "secure boot must be on for the spot pool"
  }

  assert {
    condition     = google_container_node_pool.on_demand[0].node_config[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "secure boot must be on for the on-demand pool"
  }
}

run "default_compute_sa_is_rejected" {
  command = plan

  variables {
    node_service_account = "default"
  }

  expect_failures = [var.node_service_account]
}
