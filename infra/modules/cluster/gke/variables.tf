variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "location" {
  description = "Zone for a zonal cluster (fee covered by the GKE free credit) or region for regional."
  type        = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "pods_range_name" {
  type    = string
  default = "pods"
}

variable "services_range_name" {
  type    = string
  default = "services"
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "authorized_networks" {
  description = <<-EOT
    CIDRs allowed to reach the *private IP* control-plane endpoint from inside
    the VPC (or peered networks). There is no public IP endpoint; humans and CI
    use the IAM-authenticated DNS endpoint, so this list is usually empty.
  EOT
  type        = list(string)
  default     = []
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "spot_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "spot_min_nodes" {
  type    = number
  default = 1
}

variable "spot_max_nodes" {
  type    = number
  default = 3
}

variable "on_demand_nodes" {
  description = "Fixed-size stable pool for critical pods. 0 disables it."
  type        = number
  default     = 0
}

variable "on_demand_machine_type" {
  type    = string
  default = "e2-small"
}

variable "node_disk_size_gb" {
  description = "Default GKE disk is 100 GB pd-balanced (~$10/node/mo); 20 GB pd-standard is ~$0.80."
  type        = number
  default     = 20
}

variable "node_disk_type" {
  type    = string
  default = "pd-standard"
}

variable "node_service_account" {
  description = <<-EOT
    Email of the dedicated node service account. Required: the default compute
    SA carries roles/editor, and Workload Identity protects the pod path only —
    the node path is this grant. The env stack creates it with logWriter,
    metricWriter, monitoring.viewer, resourceMetadata.writer and
    artifactregistry.reader.
  EOT
  type        = string

  validation {
    condition     = can(regex("@.*\\.iam\\.gserviceaccount\\.com$", var.node_service_account))
    error_message = "node_service_account must be a service-account email, never null (default compute SA)."
  }
}

variable "logging_components" {
  type    = list(string)
  default = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_components" {
  description = "Cloud Monitoring components. SYSTEM_COMPONENTS is free; add e.g. APISERVER deliberately."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "enable_managed_prometheus" {
  description = "GMP has no free tier; default collection can run ~$140/mo on a small cluster."
  type        = bool
  default     = false
}
