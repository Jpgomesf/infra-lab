terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The 6.11 floor is load-bearing here: `aws_eks_cluster.deletion_protection`
      # was added in provider v6.11.0 (2025-08-28), and it is what lets this
      # module honor the contract's `deletion_protection` input directly.
      version = ">= 6.11, < 7.0"
    }
  }
}
