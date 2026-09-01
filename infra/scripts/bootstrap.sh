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

echo ">> KMS key for OpenTofu state encryption"
gcloud services enable cloudkms.googleapis.com --project "${PROJECT_ID}"
gcloud kms keyrings create tofu --location "${REGION}" \
  --project "${PROJECT_ID}" 2>/dev/null || true
gcloud kms keys create state --keyring tofu --location "${REGION}" \
  --purpose encryption --project "${PROJECT_ID}" 2>/dev/null || true

echo ">> state bucket (versioned)"
if ! gcloud storage buckets describe "gs://${STATE_BUCKET}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${STATE_BUCKET}" \
    --project "${PROJECT_ID}" --location "${REGION}" \
    --uniform-bucket-level-access
fi
gcloud storage buckets update "gs://${STATE_BUCKET}" --versioning

# Versioning enables recovery; lifecycle keeps it from growing forever.
LIFECYCLE_FILE=$(mktemp)
cat > "${LIFECYCLE_FILE}" <<'JSON'
{"rule": [{"action": {"type": "Delete"}, "condition": {"daysSinceNoncurrentTime": 90}}]}
JSON
gcloud storage buckets update "gs://${STATE_BUCKET}" --lifecycle-file="${LIFECYCLE_FILE}"
rm -f "${LIFECYCLE_FILE}"

echo ">> scoped CI service account (never grant editor/owner to CI)"
SA="tofu-ci@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts create tofu-ci \
  --display-name "OpenTofu CI" --project "${PROJECT_ID}" 2>/dev/null || true
# Minimum roles for the four stacks. resourcemanager.projectIamAdmin is the
# widest one and exists because the iam capability manages project bindings.
for role in \
  roles/compute.networkAdmin \
  roles/container.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountUser \
  roles/resourcemanager.projectIamAdmin \
  roles/cloudsql.admin \
  roles/storage.admin \
  roles/servicenetworking.networksAdmin \
  roles/monitoring.editor \
  roles/logging.configWriter; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${SA}" --role "${role}" \
    --condition=None --quiet >/dev/null
done
gcloud kms keys add-iam-policy-binding state \
  --keyring tofu --location "${REGION}" --project "${PROJECT_ID}" \
  --member "serviceAccount:${SA}" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter --quiet >/dev/null
POOL_NAME=$(gcloud iam workload-identity-pools describe github \
  --project "${PROJECT_ID}" --location global --format 'value(name)')
gcloud iam service-accounts add-iam-policy-binding "${SA}" \
  --project "${PROJECT_ID}" --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/${POOL_NAME}/attribute.repository/${GITHUB_REPO}" \
  --quiet >/dev/null
echo ">> NOTE: budgets need a billing-account grant only a billing admin can make:"
echo "   gcloud billing accounts add-iam-policy-binding <ACCOUNT_ID> \\"
echo "     --member serviceAccount:${SA} --role roles/billing.costsManager"

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
echo ">> then add the state 'encryption' block from the README to each stack, using:"
echo "   projects/${PROJECT_ID}/locations/${REGION}/keyRings/tofu/cryptoKeys/state"
echo ">> and wire google-github-actions/auth to the provider printed by:"
echo "   gcloud iam workload-identity-pools providers describe github-oidc \\"
echo "     --project ${PROJECT_ID} --location global --workload-identity-pool github \\"
echo "     --format 'value(name)'"
