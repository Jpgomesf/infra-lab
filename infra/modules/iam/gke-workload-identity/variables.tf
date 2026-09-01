variable "name" {
  type = string

  validation {
    condition     = length(var.name) >= 6 && length(var.name) <= 30
    error_message = "GCP service-account IDs must be 6-30 characters."
  }
}

variable "project_id" {
  type = string
}

variable "namespace" {
  type = string
}

variable "ksa_name" {
  type = string
}

variable "roles" {
  type    = list(string)
  default = []
}
