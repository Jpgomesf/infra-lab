terraform {
  required_version = ">= 1.6"

  # GCS backend for an AWS stack — see ../network/main.tf for why.
  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "aws-dev/data"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.11, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      env        = "aws-dev"
      managed-by = "opentofu"
    }
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "aws-dev/network"
  }
}

# envs/dev/data only reads the network stack. This one also reads eks, because a
# Pod Identity association is scoped to a cluster (GKE Workload Identity binds
# at the project level and needs no cluster reference). Same apply order —
# network -> eks -> data -> platform — so the dependency is already satisfied.
#
# The ordering is stricter than it looks, and stricter than a remote-state read
# can express: CreatePodIdentityAssociation requires the eks-pod-identity-agent
# addon to already exist on the cluster, and that addon is created by the eks
# stack (which in turn waits on a node group, since the agent is a DaemonSet).
# Reading eks's outputs proves the cluster exists, not that the addon does.
# Applying this stack against a half-applied eks stack will fail here.
data "terraform_remote_state" "eks" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "aws-dev/eks"
  }
}

module "postgres" {
  source = "../../../modules/database/rds"

  name       = "lab-aws-dev"
  region     = var.region
  network_id = data.terraform_remote_state.network.outputs.network_id
  tier       = "db.t4g.micro"

  # AWS extra: RDS reaches privacy by living in the private subnets, where
  # Cloud SQL needs a Private Service Access peering.
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # Same disposability stance as envs/dev/data: rebuilt from migrations +
  # idempotent seeds, so no backups, no deletion protection, and no final
  # snapshot standing in the way of a destroy. Note the one thing AWS does not
  # give back: there is no equivalent of Cloud SQL's activation_policy =
  # "NEVER", so the only way to stop paying for this instance is to destroy the
  # stack (or stop it manually, which RDS undoes after 7 days).
  backups_enabled     = false
  deletion_protection = false

  # Reachable from inside the VPC only.
  allowed_cidr_blocks        = [data.terraform_remote_state.network.outputs.vpc_cidr]
  allowed_security_group_ids = [data.terraform_remote_state.eks.outputs.cluster_security_group_id]

  db_password = var.db_password
}

module "app_bucket" {
  source = "../../../modules/object-store/s3"

  name     = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}-app"
  location = var.region

  # No hmac_service_account_email: on AWS the workload reaches S3 through its
  # Pod Identity role, so there is no key pair to mint. The module accepts the
  # contract field and ignores it.
}

# Cloud identity for the API workload; the KSA side lives in k8s/base and is
# unchanged from GCP — Pod Identity needs no annotation on the ServiceAccount.
module "api_identity" {
  source = "../../../modules/iam/eks-pod-identity"

  name      = "lab-aws-dev-api"
  namespace = "app"
  ksa_name  = "api"

  # AWS extra: the association is cluster-scoped.
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name

  # Contract's `roles`, carrying policy ARNs on AWS rather than role names.
  # Empty by default: the bucket-scoped grant below is narrower than any AWS
  # managed policy, and least privilege beats convenience.
  roles = var.api_policy_arns

  inline_policy_json = data.aws_iam_policy_document.api_bucket.json
}

data "aws_iam_policy_document" "api_bucket" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${module.app_bucket.bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.app_bucket.bucket_arn]
  }
}
