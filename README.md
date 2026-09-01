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

## Development

```sh
make fmt    # tofu fmt
make lint   # tofu fmt -check + kustomize build both trees
```

Run `make lint` before every commit.
