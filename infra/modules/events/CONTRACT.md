# Capability contract: events (optional)

Implementations: `eventbridge/` today. A GCP implementation would be Eventarc
over Pub/Sub — **not yet written**.

> **Opt-in, like `queue`.** This capability is for *routing*: one publisher, a
> pattern-matched fan-out to several consumers that do not know about each
> other. It is not a substitute for the Postgres-backed job queue, and it is not
> a message broker — an event bus that no rule matches drops the event on the
> floor by design. Introduce it when a second consumer of the same event appears
> and you are about to write an `if` in the publisher.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Bus name |
| `rule_name` | string | Name of the example/primary routing rule |
| `event_pattern` | string | JSON matcher deciding which events the rule routes |
| `target_arn` | string | Provider handle of the consumer (a `queue` capability's queue) |
| `target_queue_url` | string | Optional; when set, the implementation grants the bus permission to deliver |

## Outputs

| Name | Meaning |
|---|---|
| `bus_id` / `bus_arn` | Provider handles for the bus |
| `rule_arn` | The routing rule, so further targets can be attached |

## Invariants

- Delivery is **at-least-once** and unordered, same as `queue`. Consumers are
  idempotent or they are wrong.
- An event that matches no rule is discarded silently. Routing coverage is the
  publisher's responsibility, not the bus's.
- The consumer is a durable queue, never a synchronous endpoint: the bus retries
  on a schedule the publisher does not control.
- Bus and rules are owned here; the queue they feed is owned by the `queue`
  capability. This module never creates a queue.
