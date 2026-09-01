# Capability contract: network

Implementations: `gcp-vpc/` today, `aws-vpc/` if we ever migrate.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Network name prefix |
| `project_id` | string | Cloud project/account identifier |
| `region` | string | Region for the subnet and NAT |
| `subnet_cidr` | string | Primary node/VM range |
| `pods_cidr` / `services_cidr` | string | Secondary ranges consumed by the cluster capability |

## Outputs

| Name | Meaning |
|---|---|
| `network_id` | Network identifier for other capabilities |
| `subnet_id` | Subnet identifier handed to the cluster capability |
| `pods_range_name` / `services_range_name` | Secondary range names |

## Invariants

- Workloads have no public IPs; outbound traffic goes through managed NAT.
- Provides private connectivity for the database capability
  (Private Service Access on GCP; the AWS implementation would use subnet groups).
