variable "project_id" {
  description = "The prod GCP project — a separate project from dev, per environment isolation."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}
