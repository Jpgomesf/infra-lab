variable "name" {
  type = string
}

variable "project_id" {
  description = "Contract input. Accepted and unused — AWS has no project; the account comes from the provider credentials."
  type        = string
  default     = null
}

variable "location" {
  description = <<-EOT
    Contract input. On GKE this picks zonal vs regional. EKS control planes are
    always regional and always multi-AZ, and the region comes from the provider
    block, so this is accepted for parity and used only in tags/names.
  EOT
  type        = string
  default     = null
}

variable "network" {
  description = <<-EOT
    Contract input: the VPC id from the network capability. Accepted and unused
    — EKS derives the VPC from `subnet_ids` and refuses a mismatch, so passing
    it explicitly would only create a way to disagree with reality.
  EOT
  type        = string
  default     = null
}

variable "subnetwork" {
  description = <<-EOT
    Contract input: the primary private subnet id. EKS refuses a single-subnet
    cluster, so this is only the fallback — pass `subnet_ids` (the AWS extra)
    with the full multi-AZ list.
  EOT
  type        = string
}

variable "subnet_ids" {
  description = "Provider-specific extra. Private subnet ids across >= 2 AZs. Empty falls back to [subnetwork], which EKS will reject at apply."
  type        = list(string)
  default     = []
}

variable "authorized_networks" {
  description = <<-EOT
    Contract-adjacent input, same name and meaning as the GKE module: CIDRs
    allowed to reach the public API endpoint. Empty list = EKS's own default of
    0.0.0.0/0 (avoid — see .trivyignore.yaml).
  EOT
  type        = list(string)
  default     = []
}

variable "enable_public_endpoint" {
  description = <<-EOT
    Whether the control-plane API is reachable from outside the VPC at all.
    true (with authorized_networks set) mirrors the GKE module's posture:
    enable_private_nodes + enable_private_endpoint = false. Setting it to false
    is strictly safer and makes the cluster unreachable from a laptop without a
    bastion or VPN — which is why the lab default is true.
  EOT
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Contract input. Native on EKS since AWS provider v6.11.0; before that there was no equivalent and this had to be a lifecycle block."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes minor version. null = whatever EKS considers latest at create time, then pinned by EKS (no auto-upgrades)."
  type        = string
  default     = null
}

variable "spot_machine_type" {
  description = "Contract input. EC2 instance type for the interruptible pool."
  type        = string
  default     = "t3a.medium"
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
  description = "Contract input. Fixed-size stable pool for critical pods. 0 disables it."
  type        = number
  default     = 0
}

variable "on_demand_machine_type" {
  type    = string
  default = "t3a.small"
}

variable "node_disk_size_gb" {
  description = "EBS gp3 root volume per node. EKS defaults to 20 GB; ~$0.08/GB/mo means 20 GB is ~$1.60/node/mo."
  type        = number
  default     = 20
}

variable "node_ami_type" {
  description = "AL2023_x86_64_STANDARD for x86, AL2023_ARM_64_STANDARD for Graviton. Must match the instance families above."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "enable_secrets_encryption" {
  description = <<-EOT
    Bring a customer-managed KMS key for envelope encryption. OFF by default,
    and that is not a security shortcut: EKS already envelope-encrypts all
    Kubernetes API data with an AWS-owned key on every cluster running 1.28 or
    later, at no cost and with no configuration. A CMK buys key ownership and
    CloudTrail visibility, not encryption — and it buys a hazard: disabling or
    deleting the key degrades the cluster "beyond recovery", which is a bad
    trade in an env designed to be destroyed and rebuilt. Turn it on where the
    audit trail is worth ~$1/mo and the key's lifecycle is managed separately.
    https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html
  EOT
  type        = bool
  default     = false
}

variable "enabled_cluster_log_types" {
  description = "Control-plane logs shipped to CloudWatch Logs. Billed at ingest (~$0.50/GB); an idle lab cluster produces very little."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "cluster_log_retention_days" {
  description = "Retention for the EKS control-plane log group. EKS creates the group implicitly with never-expire retention if this module does not."
  type        = number
  default     = 30
}
