variable "name" {
  description = "Contract input. Becomes the IAM role name."
  type        = string
}

variable "project_id" {
  description = "Contract input. Accepted and unused — AWS has no project; the account is whatever the provider credentials resolve to."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Contract input. Kubernetes namespace of the ServiceAccount being bound."
  type        = string
}

variable "ksa_name" {
  description = "Contract input. Kubernetes ServiceAccount name."
  type        = string
}

variable "roles" {
  description = <<-EOT
    Contract input, different vocabulary. On GCP these are IAM role names
    ("roles/storage.objectUser") granted on the project. On AWS the closest
    equivalent is a managed or customer-managed *policy ARN*
    ("arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"), attached to the role.
    The field name and shape are identical; the values are not portable, which
    is exactly the kind of per-cloud detail the iam capability exists to absorb.
  EOT
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Provider-specific extra, and required. A Pod Identity association is scoped to one cluster; GKE Workload Identity binds at the project level and needs no cluster reference."
  type        = string
}

variable "inline_policy_json" {
  description = "Optional least-privilege policy attached inline, for permissions no managed policy expresses narrowly enough. null skips it."
  type        = string
  default     = null
}
