variable "name" {
  type = string
}

variable "project_id" {
  description = <<-EOT
    Contract input. AWS has no project: the account is whatever the provider
    credentials resolve to. Accepted and unused so an environment can pass the
    same variable set to either implementation.
  EOT
  type        = string
  default     = null
}

variable "region" {
  description = "Contract input. The provider block already carries the region; kept for parity and used only in resource names."
  type        = string
}

variable "subnet_cidr" {
  description = <<-EOT
    Contract input, remapped: the contract offers one CIDR knob, which on GCP is
    the subnet's range. On AWS the VPC owns the range and subnets are carved out
    of it, so this value becomes the VPC CIDR and each AZ gets a slice.
  EOT
  type        = string
}

variable "pods_cidr" {
  description = <<-EOT
    Contract input, accepted and unused. EKS has no secondary ranges: the VPC CNI
    hands pods real VPC IPs out of the node subnets, so pod addressing is already
    covered by subnet_cidr. Passing it changes nothing.
  EOT
  type        = string
  default     = null
}

variable "services_cidr" {
  description = "Contract input, accepted and unused. Service IPs live in the cluster's own kubernetes_network_config range, not in the VPC."
  type        = string
  default     = null
}

variable "az_count" {
  description = "Provider-specific extra. EKS requires subnets in at least two AZs; more AZs means more NAT gateways for an HA egress path."
  type        = number
  default     = 2
}

variable "subnet_newbits" {
  description = "Bits added to subnet_cidr's prefix when slicing subnets. 4 turns a /16 into /20s."
  type        = number
  default     = 4
}

variable "public_subnet_offset" {
  description = "Index offset for the public slices, so private and public ranges never collide as az_count grows."
  type        = number
  default     = 8
}
