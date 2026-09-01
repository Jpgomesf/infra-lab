variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "state_bucket" {
  type    = string
  default = "REPLACE-tofu-state-bucket"
}

variable "authorized_networks" {
  description = "CIDRs allowed to reach the control-plane endpoint. Pass via tfvars kept out of git."
  type        = list(string)
  default     = []
}
