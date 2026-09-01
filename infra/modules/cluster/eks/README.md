# cluster/eks

AWS implementation of the [`cluster` capability](../CONTRACT.md): an EKS cluster
with a private-node posture, a Spot managed node group, an optional on-demand
group, and EKS Pod Identity.

## Contract deviations

| Contract field | What happens here | Why |
| --- | --- | --- |
| `location` (input) | accepted, unused | EKS control planes are always regional and multi-AZ. There is no zonal/regional choice to make, and the region comes from the provider block. |
| `project_id` (input) | accepted, unused | No such thing on AWS. |
| `network` (input) | accepted, unused | EKS derives the VPC from `subnet_ids`. |
| `subnetwork` (input) | fallback only | EKS rejects a single-subnet cluster. Pass the `subnet_ids` extra with the full multi-AZ list; `subnetwork` remains the declared fallback so the contract call still type-checks. |
| `deletion_protection` (input) | **native** | Was the one contract field with no EKS equivalent until AWS provider **v6.11.0** (2025-08-28) added `aws_eks_cluster.deletion_protection`. That is why every AWS module here floors the provider at 6.11. |
| `workload_pool` (output) | the cluster's OIDC issuer URL | GKE's workload pool is a name IAM policies reference. Pod Identity has no equivalent name — the binding is a resource, not a namespace. The issuer URL is the closest stable per-cluster identity handle, and is exactly what an IRSA implementation would need. |
| `spot_min_nodes` / `spot_max_nodes` | ASG bounds, not an autoscaler | GKE node pools autoscale natively. An EKS managed node group's min/max are just bounds; **something has to drive them** — Cluster Autoscaler or Karpenter. Without one installed the group sits at `desired_size`. This module does not install either; that is a `k8s/` concern. |

## Cost

| | EKS | GKE |
| --- | --- | --- |
| Control plane list price | $0.10/hr | $0.10/hr |
| Free-tier credit | **none** | $74.40/mo, covers one zonal cluster |
| Effective | **~$73/mo** | ~$0 for the first cluster |

Identical list price, opposite bill — verified on
[EKS pricing](https://aws.amazon.com/eks/pricing/). Extended support, once a
Kubernetes version ages out of its 14-month standard window, is $0.60/hr.

## Envelope encryption

`enable_secrets_encryption` defaults to **false**, which is not a shortcut. EKS
already envelope-encrypts every Kubernetes API object with an AWS-owned key on
any cluster running 1.28 or later — free, automatic, and per AWS "you don't have
to take any action"
([docs](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html)).
A customer-managed key buys key ownership and a CloudTrail record, at ~$1/mo,
plus a hazard AWS states plainly: deleting the key degrades the cluster *beyond
recovery*. In an env whose whole operating model is destroy-and-rebuild, that
trade is wrong by default. The knob exists, with the key policy the cluster role
actually needs, for the environment where the audit trail earns it.

The resulting `trivy` finding is registered in `.trivyignore.yaml` — a scanner
cannot see a platform default, which makes "secrets are not encrypted" false
here rather than merely accepted.

## Pod identity

`aws_eks_addon "eks-pod-identity-agent"` installs the DaemonSet; the actual
KSA↔role binding lives in [`iam/eks-pod-identity`](../../iam/eks-pod-identity).
Unlike GKE Workload Identity (and unlike IRSA), Pod Identity needs **no
annotation on the Kubernetes ServiceAccount** — so `k8s/base` runs on EKS with
no AWS-specific edit at all.
