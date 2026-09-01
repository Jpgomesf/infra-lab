output "identity" {
  description = "Contract output. The IAM role ARN — the contract already names this as the AWS shape."
  value       = aws_iam_role.this.arn
}

# ---- Provider-specific extras -----------------------------------------------

output "role_name" {
  description = "Extra. For attaching further policies outside this module."
  value       = aws_iam_role.this.name
}

output "association_id" {
  description = "Extra. The Pod Identity association id."
  value       = aws_eks_pod_identity_association.this.association_id
}
