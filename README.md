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
   `rds/`, `s3/` against the same contracts + a new env dir. Nothing else moves.
2. **`k8s/` — the portable layer.** Plain Kubernetes manifests
   (base + kustomize overlays): Deployments, Services, KSAs, NetworkPolicies,
   ingress-nginx routing. Runs verbatim on kind, GKE, or EKS.
3. **Console, once.** Org, billing account, payment method, startup-credits
   application. Prerequisites to `tofu apply`; never code.

App-level portability contracts: vanilla Postgres (`DATABASE_URL`), the S3 API
for objects (MinIO locally, GCS-interop in cloud), OTLP to `otel-lgtm:4317`
for all telemetry, and the job queue rides inside Postgres.

## Phase 0 — local lab

Requires: Docker running, `kind`, `kubectl` (`brew install kind kubectl`).

```sh
make lab-up       # kind cluster + ingress-nginx + the full stack
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

## Phase 1 — GCP dev

1. Console: org + billing + payment method; apply for Google for Startups.
2. `PROJECT_ID=... STATE_BUCKET=... GITHUB_REPO=... infra/scripts/bootstrap.sh`
3. Replace `REPLACE-tofu-state-bucket` in `infra/envs/dev/*/main.tf`.
4. Apply stacks in order: `network` → `gke` → `data` → `platform`
   (`tofu init && tofu apply` in each; CI takes over after the first apply).
5. Fill in `k8s/overlays/dev` (see its README).

## CI

Four workflows in `.github/workflows`. All third-party actions are pinned to a
full commit SHA with the tag in a trailing comment; Renovate (`renovate.json`)
keeps the digests current and groups the bumps into one PR.

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `lint.yml` | PR, push to `main` | `make lint` on OpenTofu 1.12.3. `kubectl` is preinstalled on the `ubuntu-latest` runner image, so nothing installs it; a `kubectl version --client` step asserts that assumption instead of letting a runner-image change fail inside the Makefile. |
| `tofu-plan.yml` | PR touching `infra/**` | `validate` (matrix over the four stacks: `tofu init -backend=false` + `tofu validate`), `trivy-config` (misconfiguration scan of `infra/`, fails on HIGH/CRITICAL), and `plan` (matrix, cloud-touching — see the guard below), which posts one PR comment per stack and updates it in place on re-runs. |
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
Cloud SQL TLS enforcement). It is an accepted-risk register, not a mute button:
anything not listed there still fails the PR at HIGH/CRITICAL.

### Checklist for when the repo is pushed

1. **Environment.** Settings → Environments → new environment `production`,
   add yourself as a required reviewer. `tofu-apply` targets it, so every apply
   pauses for approval.
2. **Ruleset.** Settings → Rules → Rulesets → new branch ruleset targeting
   `main`: require a pull request before merging; require status checks
   `make lint`, `validate (network)`, `validate (gke)`, `validate (data)`,
   `validate (platform)`, and `trivy config scan`; block force pushes; block
   deletions.
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
