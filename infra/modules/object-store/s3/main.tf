# AWS implementation of the `object-store` capability (see ../CONTRACT.md).
# This is the one capability where AWS is the reference implementation: the
# contract's portability promise is "the app always speaks the S3 API", and here
# the S3 API is not an interop layer over something else. The GCS-interop gaps
# the contract warns about (multipart 1024-part cap, no object tagging) simply
# do not exist on this side.

locals {
  # S3 lifecycle rules are day-granular; the GCS knob is seconds. Round up so a
  # sub-day retention still keeps one day rather than silently keeping nothing.
  noncurrent_days = var.soft_delete_retention_seconds == null ? null : max(1, ceil(var.soft_delete_retention_seconds / 86400))

  soft_delete_enabled = var.versioning && local.noncurrent_days != null && local.noncurrent_days > 0
}

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy
}

# Count-gated rather than a Status toggle, because S3 versioning is a one-way
# door: a bucket can go Enabled -> Suspended but never back to unversioned, and
# the API rejects `Suspended` on a bucket that was never versioned. Creating the
# resource only when versioning is wanted leaves a new bucket genuinely
# unversioned, and destroying it later suspends versioning, which is the closest
# thing to "off" that S3 offers.
resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 has applied SSE-S3 to every new object in every bucket since 2023-01-05, so
# this block is belt-and-braces rather than a fix. It is still declared, because
# "the default happens to be right" is not something a scanner or a reviewer can
# verify from the config, and because it is where SSE-KMS gets switched on.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    # Collapses per-object KMS calls into per-bucket ones; meaningless for
    # AES256, ~99% of the KMS bill when a CMK is in play.
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# The GCS module gets this for free through uniform bucket-level access. On S3
# it is four separate switches, and all four belong on.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs are the legacy access model and the reason most public-bucket incidents
# happen. Disabling them makes the bucket policy the only access path.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "soft_delete" {
  count = local.soft_delete_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "soft-delete-window"
    status = "Enabled"

    # Empty filter = every object. `prefix` is deprecated by S3 and will be
    # removed in the next provider major.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = local.noncurrent_days
    }

    # Half-finished multipart uploads bill as storage forever otherwise.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
