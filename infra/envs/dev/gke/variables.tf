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
