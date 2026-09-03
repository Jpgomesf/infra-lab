#!/usr/bin/env bash
# One-time, per-project bootstrap: APIs + KMS key + state bucket + keyless CI
# auth (Workload Identity Federation, two service accounts: plan and apply).
# Prerequisites (console, manual): org/billing account exists, payment method
# attached, project created and linked to billing.
#
# Idempotent: safe to re-run after editing (existing resources are updated or
# skipped, never duplicated).
set -euo pipefail

: "${PROJECT_ID:?set PROJECT_ID}"
: "${STATE_BUCKET:?set STATE_BUCKET (e.g. \${PROJECT_ID}-tofu-state)}"
: "${GITHUB_REPO:?set GITHUB_REPO as org/repo for CI federation}"
REGION="${REGION:-us-central1}"
# GitHub environment whose reviewer gate protects `tofu apply`. Only jobs
# running inside it can impersonate the apply SA.
APPLY_ENVIRONMENT="${APPLY_ENVIRONMENT:-production}"

# The WIF attribute condition pins the *numeric* repository and owner ids, not
# the name: a repo can be renamed or deleted and its name re-registered by
# someone else, and Google's own guidance now recommends the ids. Resolved via
# `gh` when available, otherwise pass GITHUB_REPO_ID / GITHUB_REPO_OWNER_ID.
if [[ -z "${GITHUB_REPO_ID:-}" || -z "${GITHUB_REPO_OWNER_ID:-}" ]]; then
  if command -v gh >/dev/null 2>&1; then
    GITHUB_REPO_ID=$(gh api "repos/${GITHUB_REPO}" --jq '.id')
    GITHUB_REPO_OWNER_ID=$(gh api "repos/${GITHUB_REPO}" --jq '.owner.id')
  else
    echo "gh not found: set GITHUB_REPO_ID and GITHUB_REPO_OWNER_ID (numeric ids from" >&2
    echo "https://api.github.com/repos/${GITHUB_REPO} -> .id and .owner.id)" >&2
    exit 1
  fi
fi

echo ">> enabling APIs"
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudkms.googleapis.com \
  billingbudgets.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  --project "${PROJECT_ID}"

echo ">> KMS key for OpenTofu state + plan encryption"
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

echo ">> workload identity federation for GitHub Actions (no SA keys, ever)"
# Created before anything reads it: the SA bindings below need the pool name.
gcloud iam workload-identity-pools create github \
  --project "${PROJECT_ID}" --location global \
  --display-name "GitHub Actions" 2>/dev/null || true
POOL_NAME=$(gcloud iam workload-identity-pools describe github \
  --project "${PROJECT_ID}" --location global --format 'value(name)')

ATTRIBUTE_MAPPING="google.subject=assertion.sub"
ATTRIBUTE_MAPPING+=",attribute.repository=assertion.repository"
ATTRIBUTE_MAPPING+=",attribute.repository_id=assertion.repository_id"
ATTRIBUTE_MAPPING+=",attribute.repository_owner_id=assertion.repository_owner_id"
ATTRIBUTE_CONDITION="assertion.repository_id == '${GITHUB_REPO_ID}' && assertion.repository_owner_id == '${GITHUB_REPO_OWNER_ID}'"
# create-or-update so a re-run applies a changed mapping/condition instead of
# silently keeping the old one.
if ! gcloud iam workload-identity-pools providers describe github-oidc \
  --project "${PROJECT_ID}" --location global --workload-identity-pool github >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc github-oidc \
    --project "${PROJECT_ID}" --location global \
    --workload-identity-pool github \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "${ATTRIBUTE_MAPPING}" \
    --attribute-condition "${ATTRIBUTE_CONDITION}"
else
  gcloud iam workload-identity-pools providers update-oidc github-oidc \
    --project "${PROJECT_ID}" --location global \
    --workload-identity-pool github \
    --attribute-mapping "${ATTRIBUTE_MAPPING}" \
    --attribute-condition "${ATTRIBUTE_CONDITION}"
fi

echo ">> plan service account (read-only; any ref in the repo may use it)"
PLAN_SA="tofu-plan@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts create tofu-plan \
  --display-name "OpenTofu CI plan (read-only)" --project "${PROJECT_ID}" 2>/dev/null || true
# viewer reads every resource a plan refreshes; serviceUsageConsumer lets the
# provider bill quota to the project (billing_project on the platform stack).
for role in \
  roles/viewer \
  roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${PLAN_SA}" --role "${role}" \
    --condition=None --quiet >/dev/null
done
# Plans read state (decrypt) and write an encrypted plan file (encrypt), so
# both directions on the key; only *read* on the bucket (plans run -lock=false).
gcloud storage buckets add-iam-policy-binding "gs://${STATE_BUCKET}" \
  --member "serviceAccount:${PLAN_SA}" --role roles/storage.objectViewer --quiet >/dev/null
gcloud kms keys add-iam-policy-binding state \
  --keyring tofu --location "${REGION}" --project "${PROJECT_ID}" \
  --member "serviceAccount:${PLAN_SA}" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter --quiet >/dev/null
gcloud iam service-accounts add-iam-policy-binding "${PLAN_SA}" \
  --project "${PROJECT_ID}" --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/${POOL_NAME}/attribute.repository_id/${GITHUB_REPO_ID}" \
  --quiet >/dev/null

echo ">> apply service account (scoped; only the '${APPLY_ENVIRONMENT}' environment may use it)"
SA="tofu-ci@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts create tofu-ci \
  --display-name "OpenTofu CI apply" --project "${PROJECT_ID}" 2>/dev/null || true
# Roles derived from what the four stacks create — never editor/owner.
#   projectIamAdmin + serviceAccountAdmin: the iam capability and the gke
#     stack's node SA manage project bindings (this trio is owner-equivalent
#     in practice, which is why only the reviewer-gated environment can
#     impersonate this SA).
#   artifactregistry.admin: data stack's Docker repository.
#   lienModifier: prod platform stack's project lien.
#   serviceUsageConsumer: billing_project quota on the platform provider.
for role in \
  roles/compute.networkAdmin \
  roles/container.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.serviceAccountUser \
  roles/resourcemanager.projectIamAdmin \
  roles/resourcemanager.lienModifier \
  roles/cloudsql.admin \
  roles/storage.admin \
  roles/artifactregistry.admin \
  roles/servicenetworking.networksAdmin \
  roles/serviceusage.serviceUsageConsumer \
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
# Subject-scoped: GitHub mints `repo:<org/repo>:environment:<env>` as the
# OIDC subject only for jobs running inside that environment, i.e. after the
# required reviewer approved. Any other job in the repo cannot become this SA.
gcloud iam service-accounts add-iam-policy-binding "${SA}" \
  --project "${PROJECT_ID}" --role roles/iam.workloadIdentityUser \
  --member "principal://iam.googleapis.com/${POOL_NAME}/subject/repo:${GITHUB_REPO}:environment:${APPLY_ENVIRONMENT}" \
  --quiet >/dev/null
echo ">> NOTE: budgets need billing-account grants only a billing admin can make:"
echo "   gcloud billing accounts add-iam-policy-binding <ACCOUNT_ID> \\"
echo "     --member serviceAccount:${SA} --role roles/billing.costsManager"
echo "   gcloud billing accounts add-iam-policy-binding <ACCOUNT_ID> \\"
echo "     --member serviceAccount:${PLAN_SA} --role roles/billing.viewer"

PROVIDER_NAME=$(gcloud iam workload-identity-pools providers describe github-oidc \
  --project "${PROJECT_ID}" --location global --workload-identity-pool github \
  --format 'value(name)')
echo ">> done. In infra/envs/<env>/*/main.tf replace REPLACE-tofu-state-bucket with ${STATE_BUCKET}"
echo "   and the encryption key's project placeholder with ${PROJECT_ID} (key:"
echo "   projects/${PROJECT_ID}/locations/${REGION}/keyRings/tofu/cryptoKeys/state)."
echo ">> GitHub repository variables (Settings -> Secrets and variables -> Actions):"
echo "   WIF_PROVIDER              = ${PROVIDER_NAME}"
echo "   WIF_PLAN_SERVICE_ACCOUNT  = ${PLAN_SA}"
echo "   WIF_SERVICE_ACCOUNT       = ${SA}"
