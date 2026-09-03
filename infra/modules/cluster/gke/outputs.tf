output "name" {
  value = google_container_cluster.this.name
}

output "endpoint" {
  description = "Private IP endpoint (VPC-internal only)."
  value       = google_container_cluster.this.endpoint
}

output "dns_endpoint" {
  description = "IAM-authenticated control-plane endpoint; what get-credentials --dns-endpoint uses."
  value       = try(google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint, null)
}

output "ca_certificate" {
  # try(): master_auth is computed-only, so a mocked-provider plan has none.
  value     = try(google_container_cluster.this.master_auth[0].cluster_ca_certificate, null)
  sensitive = true
}

output "workload_pool" {
  value = google_container_cluster.this.workload_identity_config[0].workload_pool
}
