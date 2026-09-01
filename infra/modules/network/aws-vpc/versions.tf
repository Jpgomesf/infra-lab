terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # v6 is the current major (6.62.0, 2026-08-26). The 6.11 floor is shared
      # across every AWS module here: it is where `aws_eks_cluster`
      # `deletion_protection` landed, and one floor beats four.
      version = ">= 6.11, < 7.0"
    }
  }
}
