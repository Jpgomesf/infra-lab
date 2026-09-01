# envs/local

There is deliberately **no OpenTofu here**. The local environment is a kind
cluster plus the same `k8s/` manifests the cloud runs — cloud IaC has nothing
to manage locally.

From the repo root:

```sh
make lab-up      # create kind cluster + ingress-nginx + apply k8s/overlays/local
make lab-status
make lab-down    # delete the cluster (fits the tear-down-when-idle habit)
```

Local stand-ins for cloud capabilities:

| Capability | Cloud (dev/prod) | Local |
|---|---|---|
| cluster | GKE Standard | kind |
| database | Cloud SQL Postgres | `postgres:16` StatefulSet |
| object-store | GCS via S3-interop | MinIO (same S3 API) |
| observability backend | Google Cloud Observability | `grafana/otel-lgtm` pod |
| iam | Workload Identity | plain K8s Secrets |
