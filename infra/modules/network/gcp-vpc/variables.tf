variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "pods_cidr" {
  type = string
}

variable "services_cidr" {
  type = string
}

variable "enable_private_service_access" {
  description = "Reserved peering range for managed services (required for Cloud SQL private IP)."
  type        = bool
  default     = true
}
