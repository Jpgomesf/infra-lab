variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  description = "GCS bucket holding this env's state — the same bucket the GCP envs use."
  type        = string
  default     = "REPLACE-tofu-state-bucket"
}

variable "authorized_networks" {
  description = "Your IP(s) in CIDR form, e.g. [\"203.0.113.7/32\"], allowed to reach the EKS public API endpoint. Never commit a real personal IP; pass via tfvars kept out of git."
  type        = list(string)
  default     = []
}
