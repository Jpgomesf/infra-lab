# Capability contract: iam (workload identity)

Implementations: `gke-workload-identity/` today; an EKS implementation would use
IRSA/Pod Identity — same shape: bind a Kubernetes ServiceAccount to a cloud
identity with roles.

The portable side of the contract lives in `k8s/base`: **apps only ever know
their Kubernetes ServiceAccount.** Everything below the KSA is per-cloud glue
owned by this capability.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Cloud identity name |
| `project_id` | string | Cloud project/account identifier |
| `namespace` / `ksa_name` | string | The Kubernetes ServiceAccount being bound |
| `roles` | list(string) | Cloud roles the workload needs (least privilege) |

## Outputs

| Name | Meaning |
|---|---|
| `identity` | Cloud identity handle (GSA email on GCP, role ARN on AWS) |

## Invariants

- No long-lived keys. Ever. Pods get short-lived credentials via the binding;
  CI gets them via OIDC federation (bootstrap script).
