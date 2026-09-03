resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  network    = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection

  # Dataplane V2 (Cilium). Without it GKE Standard accepts NetworkPolicy
  # objects and silently ignores them; the default-deny in k8s/base would be
  # decorative. Creation-time only — changing it recreates the cluster.
  datapath_provider     = "ADVANCED_DATAPATH"
  enable_shielded_nodes = true

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # No public IP endpoint. Humans and CI reach the control plane through the
  # IAM-authenticated DNS endpoint (see control_plane_endpoints_config); the
  # private IP endpoint stays for in-VPC callers and is what
  # var.authorized_networks now restricts.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      # Reachable from anywhere, but every request is IAM-authenticated and
      # needs container.clusters.connect — no CIDR allowlist to rotate.
      allow_external_traffic = true
    }
    ip_endpoints_config {
      enabled = true
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value
          display_name = "authorized"
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Both free: BASIC posture surfaces workload misconfigurations, cost
  # allocation labels usage per namespace in the billing export.
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  cost_management_config {
    enabled = true
  }

  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }
}

resource "google_container_node_pool" "spot" {
  name     = "spot"
  project  = var.project_id
  location = var.location
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = var.spot_min_nodes
    max_node_count = var.spot_max_nodes
  }

  node_config {
    machine_type    = var.spot_machine_type
    spot            = true
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "spot"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_container_node_pool" "on_demand" {
  count = var.on_demand_nodes > 0 ? 1 : 0

  name       = "on-demand"
  project    = var.project_id
  location   = var.location
  cluster    = google_container_cluster.this.name
  node_count = var.on_demand_nodes

  node_config {
    machine_type    = var.on_demand_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      pool = "on-demand"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
