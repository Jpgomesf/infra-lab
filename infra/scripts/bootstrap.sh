#!/usr/bin/env bash
# One-time, per-project bootstrap: state bucket + APIs + keyless CI auth.
# Prerequisites (console, manual): org/billing account exists, payment method
# attached, project created and linked to billing.
set -euo pipefail

: "${PROJECT_ID:?set PROJECT_ID}"
: "${STATE_BUCKET:?set STATE_BUCKET (e.g. \${PROJECT_ID}-tofu-state)}"
: "${GITHUB_REPO:?set GITHUB_REPO as org/repo for CI federation}"
REGION="${REGION:-us-central1}"

echo ">> enabling APIs"
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  iamcredentials.googleapis.com \
  billingbudgets.googleapis.com \
  --project "${PROJECT_ID}"

echo ">> state bucket (versioned)"
if ! gcloud storage buckets describe "gs://${STATE_BUCKET}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --project "${PROJECT_ID}" --location "${REGION}" \
    --uniform-bucket-level-access
fi
gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning

echo ">> workload identity federation for GitHub Actions (no SA keys, ever)"
gcloud iam workload-identity-pools create github \
  --project "${PROJECT_ID}" --location global \
  --display-name "GitHub Actions" 2>/dev/null || true

gcloud iam workload-identity-pools providers create-oidc github-oidc \
  --project "${PROJECT_ID}" --location global \
  --workload-identity-pool github \
  --issuer-uri "https://token.actions.githubusercontent.com" \
  --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition "assertion.repository == '${GITHUB_REPO}'" 2>/dev/null || true

echo ">> done. Replace REPLACE-tofu-state-bucket with ${STATE_BUCKET} in infra/envs/*/*/main.tf"
echo ">> and wire google-github-actions/auth to the provider printed by:"
echo "   gcloud iam workload-identity-pools providers describe github-oidc \\"
echo "     --project ${PROJECT_ID} --location global --workload-identity-pool github \\"
echo "     --format 'value(name)'"
