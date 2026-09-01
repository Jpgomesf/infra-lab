output "bucket" {
  description = "Contract output."
  value       = aws_s3_bucket.this.id
}

# Contract output, deliberately null. On GCS the app must be pointed at
# https://storage.googleapis.com for the interop endpoint; on AWS the S3 SDK
# resolves the regional endpoint itself from the credential chain. Emitting null
# means "leave S3_ENDPOINT unset", which is the correct configuration — not a
# missing value.
output "s3_endpoint" {
  description = "Contract output. Always null on AWS: the SDK resolves the regional endpoint itself."
  value       = null
}

# Contract outputs, deliberately null. There is no key pair to hand out: on AWS
# the workload reaches S3 with short-lived credentials from its EKS Pod Identity
# role, which is what the iam contract's "no long-lived keys, ever" invariant
# asks for. GCS needs an HMAC key only because it is emulating S3.
output "s3_access_key_id" {
  description = "Contract output. Always null on AWS — credentials come from the Pod Identity role, not a static key."
  value       = null
  sensitive   = true
}

output "s3_secret_access_key" {
  description = "Contract output. Always null on AWS — see s3_access_key_id."
  value       = null
  sensitive   = true
}

# ---- Provider-specific extras -----------------------------------------------

output "bucket_arn" {
  description = "Extra. Needed when writing least-privilege IAM policies against this bucket."
  value       = aws_s3_bucket.this.arn
}
