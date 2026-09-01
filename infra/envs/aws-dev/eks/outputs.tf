# Same output names as infra/envs/dev/gke.
output "cluster_name" {
  value = module.cluster.name
}

output "endpoint" {
  value = module.cluster.endpoint
}

# On GKE this is the workload identity pool; on EKS it is the OIDC issuer URL.
# See infra/modules/cluster/eks/README.md.
output "workload_pool" {
  value = module.cluster.workload_pool
}

# AWS-only extra: the data stack opens Postgres to this security group.
output "cluster_security_group_id" {
  value = module.cluster.cluster_security_group_id
}
