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
- Nodes run under a dedicated, minimal identity — never the cloud default
  (GKE: a required `node_service_account`; EKS: the module's own node role).
  Pod identity protects the pod path; this protects the node path.
- Pod identity is enabled: apps authenticate via their Kubernetes ServiceAccount,
  bound to a cloud identity by the `iam` capability. Apps never see cloud keys.
- NetworkPolicy objects are enforced, not merely accepted (GKE: Dataplane V2,
  a creation-time setting; EKS: documented deviation — needs the VPC CNI
  network-policy agent).
- Control-plane access is IAM-authenticated. GKE exposes no public IP endpoint:
  `kubectl` reaches it through the DNS endpoint
  (`gcloud container clusters get-credentials <name> --location <zone>
  --dns-endpoint`), so there is no personal-IP allowlist to rotate. EKS keeps
  a CIDR-restricted public endpoint (documented deviation, see
  `.trivyignore.yaml`).
- Managed metrics collection defaults OFF (no free tier); enable deliberately.

Contract tests (`tofu test`, mocked provider) pin the creation-time invariants
in `gke/tests/`; `make test-modules` runs them.
