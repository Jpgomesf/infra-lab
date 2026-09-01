output "bus_id" {
  description = "Contract output."
  value       = aws_cloudwatch_event_bus.this.id
}

output "bus_arn" {
  description = "Contract output. What a publisher's PutEvents call and its IAM policy reference."
  value       = aws_cloudwatch_event_bus.this.arn
}

output "rule_arn" {
  description = "Contract output. Attach further targets to this rule instead of duplicating the pattern."
  value       = aws_cloudwatch_event_rule.this.arn
}
