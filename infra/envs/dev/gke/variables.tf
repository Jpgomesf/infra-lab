variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "state_bucket" {
  type    = string
  default = "infra-lab-dev-6945-tofu-state"
}

variable "cluster_deletion_protection" {
  description = "Set false + apply before a destroy; true otherwise."
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "Your IP(s) in CIDR form, e.g. [\"203.0.113.7/32\"]. Never commit a real personal IP; pass via tfvars kept out of git."
  type        = list(string)
  default     = []
}
