output "name" {
  description = "Contract output."
  value       = aws_eks_cluster.this.name
}

output "endpoint" {
  description = "Contract output. Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "ca_certificate" {
  description = "Contract output. Base64 cluster CA."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

# Contract output, remapped. On GKE this is the Workload Identity pool
# (`PROJECT.svc.id.goog`) — a namespace that IAM policies reference by name.
# EKS Pod Identity has no such pool: the binding is a first-class
# `aws_eks_pod_identity_association` resource keyed by cluster + namespace + KSA,
# and the closest thing to a stable per-cluster identity namespace is the OIDC
# issuer URL. That is what is emitted here. It is also exactly what an IRSA
# implementation would need, so the field stays useful either way.
output "workload_pool" {
  description = "Contract output. The cluster's OIDC issuer URL — the EKS stand-in for GKE's workload identity pool."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# ---- Provider-specific extras -----------------------------------------------

output "cluster_security_group_id" {
  description = "Extra. The EKS-managed cluster security group; the source to allow when opening RDS to the nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "Extra. The node instance role. Pods must NOT rely on it — that is what Pod Identity is for."
  value       = aws_iam_role.node.arn
}
