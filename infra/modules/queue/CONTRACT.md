# Capability contract: queue (optional)

Implementations: `sqs/` today. A GCP implementation would be Pub/Sub with a dead
letter topic — **not yet written**, because nothing needs it yet.

> **This capability is opt-in, and deliberately unused by default.** The repo's
> job queue lives *inside Postgres* (see the `database` contract), which is what
> makes queueing portable at all: it moves with `pg_dump`, needs no second
> managed service, and costs nothing. This capability is the managed analog for
> when that is genuinely outgrown — fan-out to many consumers, retention beyond
> what a table should hold, or a throughput ceiling the database starts to feel.
> Reaching for it early buys a per-cloud dependency and a second failure mode
> in exchange for capacity nobody is using.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Queue name; the DLQ derives from it |
| `visibility_timeout_seconds` | number | How long a received message is hidden from other consumers. Must exceed the worst-case handler runtime |
| `dlq_max_receive_count` | number | Deliveries before a message is moved to the DLQ |
| `message_retention_seconds` | number | How long an undelivered message survives |
| `dlq_message_retention_seconds` | number | Retention on the DLQ — normally longer, since it is the debugging record |
| `delay_seconds` | number | Delivery delay applied to every message |

## Outputs

| Name | Meaning |
|---|---|
| `queue_id` | Provider handle for the main queue |
| `queue_url` | Endpoint a producer/consumer SDK addresses |
| `dlq_id` | Provider handle for the dead letter queue |

## Invariants

- **At-least-once delivery.** Consumers must be idempotent. No implementation
  may promise exactly-once, and application code must never assume it.
- **A DLQ is always attached.** A queue that silently drops poison messages is
  not an implementation of this contract. `dlq_max_receive_count` may be tuned;
  it may not be disabled.
- Messages are encrypted at rest.
- Ordering is not guaranteed. If ordering matters, it belongs in the database.
