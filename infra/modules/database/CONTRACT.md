# Capability contract: database

Implementations: `cloudsql/` today, `rds/` if we ever migrate.
The engine is always **vanilla PostgreSQL** — no proprietary forks or extensions
that don't exist upstream. Application code connects with a standard
`DATABASE_URL`; a migration between implementations is `pg_dump`/logical
replication, never a code change.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Instance name |
| `project_id` / `region` | string | Placement |
| `network_id` | string | From the network capability (private connectivity) |
| `tier` | string | Instance size (cheapest viable by default) |
| `availability_type` | string | `ZONAL` (dev) or `REGIONAL` (HA, ~2x cost) |
| `database_name` / `db_user` / `db_password` | string | Application database and owner |
| `deletion_protection` | bool | Must default to `true` |

## Outputs

| Name | Meaning |
|---|---|
| `private_ip` | Address the cluster reaches the DB on |
| `connection_name` | Provider-specific connector handle (GCP-only extra; envs must not require it) |
| `database_name` | Application database |

## Invariants

- No public IP. Reachable only from the private network.
- Backups + PITR on wherever the environment is not throwaway.
- `deletion_protection = true` engages BOTH layers: the IaC-side destroy guard
  and the server-side API refusal (console deletion included).
- Instance-attached backups die with the instance on every provider — the
  durable DR layer is off-instance exports to a locked bucket in a separate
  project (prod-launch item), never the instance's own backups.
- The job queue lives in this database (extension-free implementation), so it
  inherits this contract's portability.
