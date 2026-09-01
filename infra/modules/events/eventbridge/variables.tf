variable "name" {
  description = "Custom event bus name. The `default` bus is shared with every AWS service in the account; an application gets its own."
  type        = string
}

variable "rule_name" {
  type    = string
  default = "app-events"
}

variable "event_pattern" {
  description = <<-EOT
    JSON matcher. The default routes everything this application publishes,
    which is the right starting shape: one rule, one queue, narrowed later as
    consumers diverge. `source` is whatever the publisher sets on PutEvents.
  EOT
  type        = string
  default     = null
}

variable "event_source" {
  description = "Used to build the default event_pattern when none is supplied."
  type        = string
  default     = "app"
}

variable "target_arn" {
  description = "ARN of the consumer — normally a queue capability's queue ARN. null creates the bus and rule with no target."
  type        = string
  default     = null
}

variable "target_queue_url" {
  description = "URL of the target SQS queue. When set, this module writes the queue policy that lets the bus deliver to it; without it, delivery silently fails."
  type        = string
  default     = null
}

variable "dlq_arn" {
  description = "SQS queue for events EventBridge could not deliver after retries. Strongly recommended — undelivered events are otherwise lost."
  type        = string
  default     = null
}

variable "maximum_retry_attempts" {
  type    = number
  default = 10
}

variable "maximum_event_age_seconds" {
  description = "Retry window before an event is dropped or sent to the DLQ. 60 to 86400."
  type        = number
  default     = 3600
}
