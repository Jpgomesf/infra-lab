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
  description = "Your IP(s) in CIDR form, e.g. [\"203.0.113.7/32\"]. Never commit a real personal IP; pass via tfvars kept out of git."
  type        = list(string)
  default     = []
}
