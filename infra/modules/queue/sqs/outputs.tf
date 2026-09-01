output "queue_id" {
  description = "Contract output. On SQS the id and the URL are the same string."
  value       = aws_sqs_queue.this.id
}

output "queue_url" {
  description = "Contract output. What a producer/consumer SDK addresses."
  value       = aws_sqs_queue.this.url
}

output "dlq_id" {
  description = "Contract output."
  value       = aws_sqs_queue.dlq.id
}

# ---- Provider-specific extras -----------------------------------------------

output "queue_arn" {
  description = "Extra. Needed for IAM policies and EventBridge targets."
  value       = aws_sqs_queue.this.arn
}

output "dlq_arn" {
  description = "Extra."
  value       = aws_sqs_queue.dlq.arn
}
