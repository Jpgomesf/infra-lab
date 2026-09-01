# Capability contract: object-store

Implementations: `gcs/` today, `s3/` if we ever migrate; MinIO plays this role
in the local lab. Application code always speaks the **S3 API** (standard S3
SDK + endpoint + key pair), so swapping implementations is a config change.

## Inputs

| Name | Type | Meaning |
|---|---|---|
| `name` | string | Bucket name (globally unique) |
| `project_id` / `location` | string | Placement |
| `versioning` | bool | Object versioning |
| `hmac_service_account_email` | string | SA the S3-compatible key pair is minted for (null = skip) |

## Outputs

| Name | Meaning |
|---|---|
| `bucket` | Bucket name |
| `s3_endpoint` | Endpoint the S3 SDK points at |
| `s3_access_key_id` / `s3_secret_access_key` | Key pair for the S3 SDK (sensitive) |

## Invariants

- Consumers never import a provider-native storage client — S3 SDK only.
- Known GCS-interop gaps (multipart 1024-part cap, no object tagging, SDK
  checksum env vars) are documented in the blueprint; keep usage inside the
  common subset.
