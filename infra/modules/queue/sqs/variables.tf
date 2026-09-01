variable "name" {
  type = string
}

variable "visibility_timeout_seconds" {
  description = "Must exceed the worst-case handler runtime, or a slow consumer's message is redelivered while it is still being processed."
  type        = number
  default     = 30
}

variable "dlq_max_receive_count" {
  description = "Deliveries before a message moves to the DLQ. Contract invariant: a DLQ is always attached, so this has no 'off'."
  type        = number
  default     = 5

  validation {
    condition     = var.dlq_max_receive_count >= 1
    error_message = "dlq_max_receive_count must be >= 1: the contract requires a DLQ."
  }
}

variable "message_retention_seconds" {
  description = "60 to 1209600 (14 days). SQS default is 4 days."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Longer than the main queue by default — the DLQ is the debugging record, and 14 days is the SQS maximum."
  type        = number
  default     = 1209600
}

variable "delay_seconds" {
  description = "Delivery delay on every message, 0 to 900."
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long polling. 20 is the maximum and the sane default: it collapses empty-receive request charges by orders of magnitude."
  type        = number
  default     = 20
}

variable "max_message_size" {
  description = "Bytes, 1024 to 262144. Larger payloads belong in the object store with a pointer in the message."
  type        = number
  default     = 262144
}

variable "kms_key_id" {
  description = "Customer-managed KMS key. null uses SSE-SQS (SQS-owned keys), which is free and satisfies encryption at rest."
  type        = string
  default     = null
}
