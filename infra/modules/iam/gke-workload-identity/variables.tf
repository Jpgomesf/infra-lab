variable "name" {
  type = string
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
