# AWS implementation of the optional `queue` capability (see ../CONTRACT.md).
#
# COST — 1 million requests/month are free, then ~$0.40 per million on standard
# queues (verified via https://aws.amazon.com/sqs/pricing/). Note "requests",
# not "messages": every send, receive and delete is one, and an empty poll
# counts. Long polling (receive_wait_time_seconds = 20, below) is what keeps an
# idle consumer from burning the free tier on nothing.

locals {
  # SSE-SQS unless a customer-managed key is supplied. Either way the contract's
  # encryption-at-rest invariant holds; only the key ownership differs.
  use_sqs_managed_sse = var.kms_key_id == null
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name}-dlq"

  message_retention_seconds = var.dlq_message_retention_seconds
  max_message_size          = var.max_message_size

  sqs_managed_sse_enabled           = local.use_sqs_managed_sse
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_key_id != null ? 300 : null

  tags = {
    Name = "${var.name}-dlq"
  }
}

resource "aws_sqs_queue" "this" {
  name = var.name

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  max_message_size           = var.max_message_size

  sqs_managed_sse_enabled           = local.use_sqs_managed_sse
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_key_id != null ? 300 : null

  # Contract invariant: a DLQ is always attached. maxReceiveCount must be a
  # JSON number, not a string — the provider is strict about it.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.dlq_max_receive_count
  })

  tags = {
    Name = var.name
  }
}

# The other half of the redrive pair: without this the DLQ accepts redrives from
# any queue in the account.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.this.arn]
  })
}
