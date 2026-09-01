# Capability contract: cluster

Every implementation (`gke/` today, `eks/` if we ever migrate) must accept these
inputs and emit these outputs. Environments may depend **only** on this contract —
never on provider-specific extras an implementation happens to expose.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Cluster name |
| `project_id` | string | Cloud project/account identifier |
| `location` | string | Zone or region |
| `network` / `subnetwork` | string | IDs from the `network` capability |
| `spot_machine_type` | string | Machine type for the interruptible pool |
| `spot_min_nodes` / `spot_max_nodes` | number | Autoscaling bounds |
| `on_demand_nodes` | number | 0 disables the stable pool |
| `deletion_protection` | bool | Must default to `true` |

## Outputs

| Name | Meaning |
|---|---|
| `name` | Cluster name |
| `endpoint` | API server endpoint |
| `ca_certificate` | Cluster CA (sensitive) |
| `workload_pool` | Pod-identity pool identifier (WI on GKE, IRSA-equivalent on EKS) |

## Invariants

- Nodes are private; egress goes through the network capability's NAT.
- Pod identity is enabled: apps authenticate via their Kubernetes ServiceAccount,
  bound to a cloud identity by the `iam` capability. Apps never see cloud keys.
- Managed metrics collection defaults OFF (no free tier); enable deliberately.
