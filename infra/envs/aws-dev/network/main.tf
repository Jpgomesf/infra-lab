terraform {
  required_version = ">= 1.6"

  # State stays on GCS even for the AWS environment, deliberately. One backend
  # means one bootstrap, one lifecycle policy, one KMS key to encrypt state
  # with, and one place to look when a lock is stuck. The state backend is an
  # operational concern; it has nothing to do with which cloud the resources
  # live in, and coupling the two would double the bootstrap for no benefit.
  # Consequence: `tofu init` here needs Google credentials AND `plan`/`apply`
  # need AWS credentials. See ../README.md.
  backend "gcs" {
    bucket = "REPLACE-tofu-state-bucket"
    prefix = "aws-dev/network"
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

module "vpc" {
  source = "../../../modules/network/aws-vpc"

  name   = "lab-aws-dev"
  region = var.region

  # Distinct from the GCP envs (dev 10.10/10.20/10.30, prod 10.40/10.50/10.60)
  # so the networks could be peered or VPN'd together later without overlap.
  # On AWS this one CIDR is the VPC range; the module slices /20s out of it,
  # two private and two public, one pair per AZ.
  subnet_cidr = "10.70.0.0/16"

  # Passed to prove the contract call is unchanged across implementations.
  # Both are accepted and ignored here: EKS has no secondary ranges, and the
  # VPC CNI gives pods real addresses out of the private subnets above.
  pods_cidr     = "10.71.0.0/16"
  services_cidr = "10.72.0.0/20"
}
