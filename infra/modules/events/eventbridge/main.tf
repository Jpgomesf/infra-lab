# AWS implementation of the optional `events` capability (see ../CONTRACT.md).
#
# COST — events published by AWS services onto a bus are free; custom events
# (anything this application PutEvents) are ~$1.00 per million, metered in 64 KB
# chunks, so a 100 KB event bills as two. Verified on
# https://aws.amazon.com/eventbridge/pricing/. At any volume a small app
# produces this is rounding error, which is exactly why it is easy to reach for
# EventBridge before the Postgres queue has actually been outgrown.

locals {
  # Route everything this application publishes unless the caller narrows it.
  event_pattern = coalesce(var.event_pattern, jsonencode({ source = [var.event_source] }))

  wire_target = var.target_arn != null
}

resource "aws_cloudwatch_event_bus" "this" {
  name        = var.name
  description = "Application event bus for ${var.name}"
}

resource "aws_cloudwatch_event_rule" "this" {
  name           = var.rule_name
  description    = "Routes ${var.event_source} events to the application queue"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern  = local.event_pattern
  state          = "ENABLED"
}

resource "aws_cloudwatch_event_target" "queue" {
  count = local.wire_target ? 1 : 0

  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id      = "queue"
  arn            = var.target_arn

  # Without this, an event that fails every retry is simply gone.
  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != null ? [1] : []
    content {
      arn = var.dlq_arn
    }
  }

  retry_policy {
    maximum_retry_attempts       = var.maximum_retry_attempts
    maximum_event_age_in_seconds = var.maximum_event_age_seconds
  }
}

# EventBridge does not assume a role to reach SQS — the queue's own resource
# policy has to allow it, scoped to this rule so the bus cannot be used as a
# confused deputy to write into the queue from some other rule.
data "aws_iam_policy_document" "target_queue" {
  count = local.wire_target && var.target_queue_url != null ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.target_arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.this.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "target" {
  count = local.wire_target && var.target_queue_url != null ? 1 : 0

  queue_url = var.target_queue_url
  policy    = data.aws_iam_policy_document.target_queue[0].json
}
