# overlays/dev (stub — Phase 1)

When the GCP dev cluster exists, this overlay will:

- set `images:` to the Artifact Registry paths
- annotate the `api`/`mcp-server` KSAs with `iam.gke.io/gcp-service-account`
  (identities come from `infra/envs/dev/data`)
- replace the in-cluster `postgres` and `minio` with `ExternalSecret`-fed
  `DATABASE_URL` / S3 credentials pointing at Cloud SQL and GCS-interop
- replace `otel-lgtm` with an OTel collector Deployment exporting to
  Google Cloud Observability (same `otel-lgtm:4317` Service name, so base
  manifests don't change)
