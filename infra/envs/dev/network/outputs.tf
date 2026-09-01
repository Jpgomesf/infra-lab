output "network_id" {
  value = module.vpc.network_id
}

output "subnet_id" {
  value = module.vpc.subnet_id
}

output "pods_range_name" {
  value = module.vpc.pods_range_name
}

output "services_range_name" {
  value = module.vpc.services_range_name
}
