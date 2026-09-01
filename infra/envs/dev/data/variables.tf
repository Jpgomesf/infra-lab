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

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_activation_policy" {
  description = "Flip to NEVER to stop the dev instance while idle."
  type        = string
  default     = "ALWAYS"
}
