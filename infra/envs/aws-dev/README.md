# envs/aws-dev — the portability proof

This environment exists for two reasons, in this order:

1. **To make the layering rule falsifiable.** The root README claims that
   migrating clouds means writing `infra/modules/*/aws-*` against the same
   contracts plus one new env dir, and that nothing else moves. That claim is
   free to make and easy to be wrong about. This directory is the test: it
   composes the same five capabilities, with the same variable names, reading
   the same contract outputs, and `k8s/` is untouched. Where the mapping did not
   hold, the deviation is written down in the module's README rather than
   smoothed over — see the table in each of `network/aws-vpc`, `cluster/eks`,
   `database/rds`, `object-store/s3`, `iam/eks-pod-identity`.
2. **As an AWS lab.** EKS, Pod Identity, RDS, SQS and EventBridge are worth
   having hands on, and a working stack beats reading about one.

It is **not** a second production environment and is not on the promotion path.

## Cost warning — read before `apply`

AWS charges for things GCP gives away here, and it charges by the hour whether
or not anything is running:

| Item | Cost | GCP equivalent |
| --- | --- | --- |
| EKS control plane | **~$73/mo** ($0.10/hr, **no free-tier credit**) | GKE zonal, covered by the $74.40/mo credit — effectively $0 |
| NAT gateway | **~$33/mo** ($0.045/hr) + $0.045/GB | Cloud NAT, ~$2/mo at this size |
| **Subtotal, before any workload** | **~$106/mo** | **~$2/mo** |
| 1x t3a.medium Spot node | ~$8/mo | comparable |
| db.t4g.micro RDS + 20 GB | ~$14/mo | db-f1-micro, ~$10/mo |
| **Running the stack** | **~$128/mo** | ~$25/mo, and stoppable |

Prices verified 2026-09 against
[EKS](https://aws.amazon.com/eks/pricing/),
[VPC](https://aws.amazon.com/vpc/pricing/) and
[RDS](https://aws.amazon.com/rds/pricing/) pricing.

Two consequences worth internalising:

- **Run this as apply-then-destroy sessions.** There is no idle mode. GCP's dev
  env has one — Cloud SQL's `activation_policy = "NEVER"` stops compute billing
  while keeping storage — and RDS has no equivalent (a manual stop lasts 7 days,
  then AWS restarts the instance for you). Destroy the stacks in reverse order
  when you are done: `platform` → `data` → `eks` → `network`.
- **The 12-month free tier may not apply to you.** AWS replaced it in July 2025
  with a credit pool for accounts created after 2025-07-15. On such an account
  db.t4g.micro is billed from the first hour. The `platform` stack's budget is
  the backstop, not the free tier.

## Prerequisites

**Console, once** (the third layer from the root README — never code):

1. An AWS account with a payment method. A dedicated account, not one shared
   with anything that matters — the blast radius of a lab should be an account
   boundary.
2. Enable IAM Identity Center or create an admin user; never use root day to
   day.
3. Nothing else. Budgets, VPC, cluster, database and identities are all code
   below this line.

**Credentials — and the one wrinkle in this env:**

State lives on **GCS**, the same bucket the GCP environments use, under the
`aws-dev/<stack>` prefixes. That is deliberate: one backend means one bootstrap,
one lifecycle policy, one KMS key for state encryption and one place to look
when a lock is stuck. The state backend is an operational concern and has
nothing to do with which cloud the resources are in.

The price of that decision is two credential sets:

| Command | Needs |
| --- | --- |
| `tofu init -backend=false && tofu validate` | **nothing** — fully offline. This is what CI runs. |
| `tofu init` | Google credentials (the GCS backend) |
| `tofu plan` / `tofu apply` | Google credentials **and** AWS credentials |

Locally that is `gcloud auth application-default login` plus an AWS profile
(`AWS_PROFILE=...`). Replace `REPLACE-tofu-state-bucket` in each stack's
`main.tf` first, exactly as in Phase 1.

## Apply order

Same hard dependency chain as the GCP envs — `eks` and `data` read `network`'s
outputs through `terraform_remote_state`, and `data` additionally reads `eks`,
because an EKS Pod Identity association is scoped to a cluster (GKE Workload
Identity binds at the project level and needs no cluster reference):

```sh
network → eks → data → platform
```

`TF_VAR_db_password` and `TF_VAR_budget_notification_email` have no defaults.

## CI

The `validate` job in `.github/workflows/tofu-plan.yml` covers all four stacks
here — offline, no credentials, green from the first push. `plan` and `apply`
remain GCP-only. Arming them for AWS needs
`aws-actions/configure-aws-credentials` with a GitHub OIDC role in the AWS
account, guarded by an `AWS_ROLE_ARN` repo variable the same way `WIF_PROVIDER`
guards the GCP jobs.

## What runs on top

`k8s/` runs **unchanged**. That is the whole claim, and the details that make it
true are worth stating:

- **Envoy Gateway and the HTTPRoutes are identical.** The routes attach to a
  `Gateway` named `lab` in the `app` namespace; the overlay supplies the
  `Gateway`, and only that.
- **No ServiceAccount annotation.** GKE Workload Identity needs an
  `iam.gke.io/gcp-service-account` annotation on the KSA — a GCP-shaped string
  inside `k8s/base`. EKS Pod Identity needs *nothing* on the KSA: the binding is
  an `aws_eks_pod_identity_association` owned entirely by the `iam` module. AWS
  is the cleaner side of this particular contract.
- **`DATABASE_URL` is a vanilla Postgres URL** either way, built from the
  `database` capability's outputs.
- **The app never sees a cloud key.** Short-lived credentials from the Pod
  Identity role, per the `iam` contract's invariant. The `object-store` module
  returns `null` for the S3 key pair on purpose.
- **ExternalSecrets would point at AWS Secrets Manager** instead of GCP Secret
  Manager — a change of `SecretStore` backend in the overlay, not of any base
  manifest.

See `k8s/overlays/aws-dev/README.md`.
