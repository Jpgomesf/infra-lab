variable "name" {
  description = "Contract input. Bucket name, globally unique."
  type        = string
}

variable "project_id" {
  description = "Contract input. Accepted and unused — AWS has no project."
  type        = string
  default     = null
}

variable "location" {
  description = "Contract input. Accepted for parity; an S3 bucket is created in the provider's region, and there is no per-resource override."
  type        = string
  default     = null
}

variable "versioning" {
  type    = bool
  default = false
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "hmac_service_account_email" {
  description = <<-EOT
    Contract input, accepted and unused. On GCS this mints an HMAC key pair so
    the app can speak S3. On AWS the app already speaks S3 natively and gets its
    credentials from EKS Pod Identity — minting a static key pair here would
    violate the iam contract's "no long-lived keys, ever" invariant.
  EOT
  type        = string
  default     = null
}

variable "soft_delete_retention_seconds" {
  description = <<-EOT
    Contract-adjacent knob, same name as the GCS module. S3 has no soft delete;
    the equivalent is versioning plus a noncurrent-version expiry, so when
    versioning is on this becomes exactly that (rounded up to whole days, S3's
    only unit). Ignored when versioning is off, because there is nothing to
    retain. null = no lifecycle rule.
  EOT
  type        = number
  default     = null
}

variable "kms_key_arn" {
  description = "Customer-managed key for SSE-KMS. null uses SSE-S3 (AES256), which is free; SSE-KMS adds per-request KMS charges."
  type        = string
  default     = null
}
