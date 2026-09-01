variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket" {
  type    = string
  default = "REPLACE-tofu-state-bucket"
}

variable "bucket_prefix" {
  description = "S3 bucket names are globally unique across all of AWS; the account id is appended to make collisions impossible."
  type        = string
  default     = "lab-aws-dev"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "api_policy_arns" {
  description = <<-EOT
    The iam capability's `roles` list, carrying IAM policy ARNs on AWS. Empty by
    default: the bucket grant the api actually needs is written inline and
    scoped to one bucket, which no AWS managed policy matches.
  EOT
  type        = list(string)
  default     = []
}
