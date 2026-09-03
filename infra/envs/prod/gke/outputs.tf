output "cluster_name" {
  value = module.cluster.name
}

output "endpoint" {
  value = module.cluster.endpoint
}

output "workload_pool" {
  value = module.cluster.workload_pool
}

output "dns_endpoint" {
  value = module.cluster.dns_endpoint
}
