# overlays/dev

Live overlay for the GKE dev cluster (first applied 2026-09-01; the dev
environment is torn down between sessions and rebuilt from the runbook). Today
it pins the real `api` image digest from Artifact Registry, supplies the
`Gateway` for Envoy Gateway on GKE, and deletes the local stand-ins the cloud
replaces. Still open here, in order:

- move the image pin from the inline patch to an `images:` block, so the
  release workflow's `kustomize edit set image` bump is not a silent no-op
- annotate the `api`/`mcp-server` KSAs with `iam.gke.io/gcp-service-account`
  (identities come from `infra/envs/dev/data`) and drop the HMAC-key Secret
- replace the in-cluster `postgres` and `minio` with `ExternalSecret`-fed
  `DATABASE_URL` / S3 credentials pointing at Cloud SQL and GCS-interop
- replace `otel-lgtm` with an OTel collector Deployment exporting to
  Google Cloud Observability (same `otel-lgtm:4317` Service name, so base
  manifests don't change)
