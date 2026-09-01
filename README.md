# infra-lab

A local Kubernetes lab (Phase 0) that grows into GCP dev/prod (Phases 1–2)
without rewriting the application layer. Design rationale and verified pricing
live in the internal cloud blueprint document.

## The layering rule

Everything sorts into one of three layers, and **what needs rewriting on a
cloud migration must not spill out of layer 1**:

1. **`infra/` — per-cloud IaC (OpenTofu).** Capability-based modules
   (`cluster`, `network`, `database`, `object-store`, `iam`), each with a
   `CONTRACT.md`. Environments compose implementations and may depend only on
   contract inputs/outputs. Migrating to AWS = writing `eks/`, `aws-vpc/`,
   `rds/`, `s3/` against the same contracts + a new env dir. Nothing else moves
   — and that is no longer a claim: those four modules, plus
   `iam/eks-pod-identity`, exist and are composed by `infra/envs/aws-dev`, with
   every place the mapping did *not* hold written down in the module's README
   instead of smoothed over (see [AWS lab](#aws-lab)).
2. **`k8s/` — the portable layer.** Plain Kubernetes manifests
   (base + kustomize overlays): Deployments, Services, KSAs, NetworkPolicies,
   Gateway API HTTPRoutes. Runs verbatim on kind, GKE, or EKS.
3. **Console, once.** Org, billing account, payment method, startup-credits
   application. Prerequisites to `tofu apply`; never code.

App-level portability contracts: vanilla Postgres (`DATABASE_URL`), the S3 API
for objects (MinIO locally, GCS-interop in cloud), OTLP to `otel-lgtm:4317`
for all telemetry, and the job queue rides inside Postgres.

## Phase 0 — local lab

Requires: Docker running, `kind`, `kubectl` (`brew install kind kubectl`).

```sh
make lab-up       # kind cluster + Envoy Gateway + the full stack
make lab-status
make lab-down     # tear down when done working
```

Endpoints (after `lab-up`): [api.localtest.me](http://api.localtest.me) ·
[mcp.localtest.me](http://mcp.localtest.me) ·
[grafana.localtest.me](http://grafana.localtest.me) ·
[minio.localtest.me](http://minio.localtest.me)

The `api` and `mcp-server` Deployments run a stand-in image
(`traefik/whoami`); swap them via the overlay `images:` block once the real
services have images.

### Routing: Gateway API, not Ingress

SIG Network announced ingress-nginx's retirement on **2025-11-11**; maintenance
was best-effort until March 2026 and the repository was **archived on
2026-03-24** — no more releases, bugfixes, or CVE fixes. Its own README now
tells new users to pick a Gateway API implementation instead. So the lab routes
through **Gateway API**, with **Envoy Gateway** (a CNCF Envoy subproject) as the
in-cluster implementation, pinned in the `Makefile` to `v1.9.1`. That one
install manifest also carries the Gateway API `v1.6.1` CRDs, so there is no
separate CRD install step.

The split follows the layering rule above:

| Where | What | Why |
| --- | --- | --- |
| `k8s/base/httproutes.yaml` | one `HTTPRoute` per exposed service | portable — every environment routes the same way, only `spec.hostnames` changes |
| `k8s/overlays/local/gateway.yaml` | `GatewayClass` + `Gateway` + `EnvoyProxy` | implementation- and cluster-specific |

The routes attach to a `Gateway` named `lab` in the `app` namespace, so a cloud
overlay only has to supply its own `Gateway` under that name. Everything sits in
one namespace, which keeps `parentRefs` simple and needs no `ReferenceGrant`.

Reaching it from macOS: `*.localtest.me` resolves to `127.0.0.1`, the
`EnvoyProxy` resource pins the Envoy Service to `NodePort` **30080**, and
`kind.yaml` publishes host port 80 to it. Two details matter and are easy to get
wrong — `externalTrafficPolicy` must be `Cluster` (it defaults to `Local`, which
would drop traffic arriving at the control-plane node while Envoy runs on the
worker), and the nodePort number has to come from a `patch`, because Envoy
Gateway's `envoyService` has no `ports` field.

> The manifests are schema-validated against the pinned v1.9.1 CRDs, but the
> runtime path is **unverified** until the next `make lab-up` — it was written
> with the Docker daemon deliberately down.

## Phase 1 — GCP dev

1. Console: org + billing + payment method; apply for Google for Startups.
2. `PROJECT_ID=... STATE_BUCKET=... GITHUB_REPO=... infra/scripts/bootstrap.sh`
3. Replace `REPLACE-tofu-state-bucket` in `infra/envs/dev/*/main.tf`.
4. Apply stacks in order: `network` → `gke` → `data` → `platform`
   (`tofu init && tofu apply` in each; CI takes over after the first apply).
5. Fill in `k8s/overlays/dev` (see its README).

## Phase 2 — GCP prod

`infra/envs/prod` mirrors dev in a **separate GCP project** (quota, IAM, and
blast-radius isolation — Google's own recommended pattern) with prod knobs:
an on-demand node floor, an SLA-eligible Cloud SQL tier with backups + PITR,
bucket versioning, distinct CIDRs, a bigger budget. Run `bootstrap.sh` against
the prod project, replace the state-bucket placeholder in
`infra/envs/prod/*/main.tf`, apply stacks in the same order, then fill in
`k8s/overlays/prod` (see its README). Deploys arrive via the promotion PR —
merging it is the prod deploy. Upgrade triggers are documented in place:
regional control plane and Cloud SQL HA when uptime = revenue.

The dev database is deliberately disposable — no backups, no deletion
protection, rebuilt from migrations + idempotent seeds — and stoppable while
idle (`db_activation_policy = "NEVER"`), which halts compute billing.

## AWS lab

`infra/envs/aws-dev` is the falsification test for the layering rule above: the
same five capabilities, the same variable names, the same contract outputs, on
EKS / VPC / RDS / S3 / Pod Identity — and `k8s/` untouched. Two optional
capabilities live only on this side so far, `queue/sqs` and `events/eventbridge`
(the app's default queue stays inside Postgres; those are the managed analogs
for when that is outgrown).

Three things are worth knowing before running it, all covered in
**[`infra/envs/aws-dev/README.md`](infra/envs/aws-dev/README.md)**:

- **Cost.** ~$106/mo before a single pod runs, ~$128/mo with a node and the
  database. The EKS control plane is $0.10/hr with **no**
  free-tier credit, where GKE's identical list price is covered by a $74.40/mo
  zonal credit; a NAT gateway adds ~$33/mo where Cloud NAT costs ~$2. There is
  no RDS equivalent of Cloud SQL's `activation_policy = "NEVER"`, so the env is
  designed for apply-then-destroy sessions rather than idling.
- **State stays on GCS**, in the same bucket, under `aws-dev/<stack>`. One
  backend regardless of target cloud — which means `plan`/`apply` need both
  Google and AWS credentials, while `validate` needs neither.
- **The contract deviations are documented, not hidden.** EKS has no secondary
  ranges (`pods_range_name` is `null`), the singular `subnet_id` stays singular
  while EKS reads a `private_subnet_ids` extra, RDS has no private IP so
  `private_ip` carries the DNS name, S3 returns `null` for the key pair because
  Pod Identity makes static keys unnecessary, and the `iam` capability's `roles`
  list carries policy ARNs instead of role names.

## CI

Four workflows in `.github/workflows`. All third-party actions are pinned to a
full commit SHA with the tag in a trailing comment; Renovate (`renovate.json`)
keeps the digests current and groups the bumps into one PR.

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `lint.yml` | PR, push to `main` | `make lint` on OpenTofu 1.12.3. `kubectl` is preinstalled on the `ubuntu-latest` runner image, so nothing installs it; a `kubectl version --client` step asserts that assumption instead of letting a runner-image change fail inside the Makefile. |
| `tofu-plan.yml` | PR touching `infra/**` | `validate` (`tofu init -backend=false` + `tofu validate` over twelve `{env, stack}` pairs — dev ×4, prod ×4, aws-dev ×4 — as an explicit `include:` list, because the cluster stack is `gke` in the GCP envs and `eks` in the AWS one, so a cross product would ask for stacks that do not exist), `trivy-config` (misconfiguration scan of `infra/`, fails on HIGH/CRITICAL), and `plan` (matrix, cloud-touching — see the guard below), which posts one PR comment per stack and updates it in place on re-runs. `plan`/`apply` stay dev-scoped. |
| `tofu-apply.yml` | push to `main` touching `infra/**` | Single job in the `production` environment: `tofu init` + `tofu apply -auto-approve` over `network` → `gke` → `data` → `platform`, stopping at the first failure. The order is a hard dependency — `gke` and `data` read `network`'s outputs through `terraform_remote_state`. |
| `zizmor.yml` | PR touching `.github/workflows/**` | zizmor at the default `regular` persona. Blocking: findings fail the check. |

Least privilege throughout: every workflow declares `permissions: contents:
read` at the top level, and only the jobs that authenticate to GCP elevate to
`id-token: write` (plus `pull-requests: write` on the plan job, to comment).
The PR workflows cancel superseded runs; `tofu-apply` never cancels in
progress, because a half-applied stack still holds the state lock.

### The pre-bootstrap guard

Everything that touches GCP is wrapped in `if: vars.WIF_PROVIDER != ''`. Until
that repo variable is set, the `plan` and `apply` jobs are **skipped, not
failed**, so the pipeline is green from the very first push — before an org,
a billing account, or a project exists. Setting the variable after
`infra/scripts/bootstrap.sh` is what turns CI on.

Repository **variables** (Settings → Secrets and variables → Actions →
Variables):

| Variable | Value |
| --- | --- |
| `WIF_PROVIDER` | Full provider resource name printed at the end of `bootstrap.sh`. Setting it arms `plan`/`apply`. |
| `WIF_SERVICE_ACCOUNT` | Email of the service account CI impersonates. |
| `GCP_PROJECT_ID` | → `TF_VAR_project_id`. |
| `GCP_PROJECT_NUMBER` | → `TF_VAR_project_number` (the `platform` stack's budget filter). |
| `TF_STATE_BUCKET` | → `TF_VAR_state_bucket`, the bucket the `terraform_remote_state` lookups read. |

Repository **secrets**: `BILLING_ACCOUNT_ID`, `DB_PASSWORD`.

Only variables with no usable default are wired through: an unset repo variable
expands to an empty string, and `TF_VAR_x=""` overrides a default instead of
falling back to it. `region` therefore keeps its `us-central1` default in
`variables.tf`.

Replacing `REPLACE-tofu-state-bucket` in `infra/envs/dev/*/main.tf` (Phase 1,
step 3) is a prerequisite for the guarded jobs — the backend block is read
before any variable is.

### Accepted scan findings

`.trivyignore.yaml` holds the accepted `trivy config` findings, each with a
written rationale (GKE legacy metadata endpoints, master authorized networks,
and the EKS public control-plane endpoint — the AWS twin of the second one,
accepted for the same reason and to be retired alongside it).
It is an accepted-risk register, not a mute button:
anything not listed there still fails the PR at HIGH/CRITICAL.

### Checklist for when the repo is pushed

1. **Environment.** Settings → Environments → new environment `production`,
   add yourself as a required reviewer. `tofu-apply` targets it, so every apply
   pauses for approval.
2. **Ruleset.** Settings → Rules → Rulesets → new branch ruleset targeting
   `main`: require a pull request before merging; require status checks
   `make lint`, `validate (dev/…)`, `validate (prod/…)` and
   `validate (aws-dev/…)` for each of their four stacks, and
   `trivy config scan`; block force pushes; block deletions.
   (Confirm exact check names against the first PR's check list.)
3. **Renovate.** Install the Renovate GitHub App on the repo; it picks up
   `renovate.json` and opens the onboarding PR.
4. **Bootstrap, then arm CI.** Run `infra/scripts/bootstrap.sh`, then set the
   variables and secrets above. `plan` and `apply` go from skipped to live.

## State encryption (Phase 1, recommended)

`sensitive = true` only redacts CLI output — secrets land in plaintext in the
GCS state file. After `bootstrap.sh` creates the KMS key, add this block to
each stack's `terraform {}` in `infra/envs/*/*/main.tf`:

```hcl
encryption {
  key_provider "gcp_kms" "state" {
    kms_encryption_key = "projects/PROJECT/locations/us-central1/keyRings/tofu/cryptoKeys/state"
    key_length         = 32
  }
  method "aes_gcm" "state" {
    keys = key_provider.gcp_kms.state
  }
  state {
    method   = method.aes_gcm.state
    enforced = true
  }
  plan {
    method = method.aes_gcm.state
  }
}
```

Note: encrypted state is OpenTofu-only — Terraform proper cannot read it back.

## Development

```sh
make fmt    # tofu fmt
make lint   # tofu fmt -check + kustomize build both trees
```

Run `make lint` before every commit — CI runs exactly the same target.
