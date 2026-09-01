# Contract outputs, same names as infra/envs/dev/network.
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

# AWS-only extras, read by the eks and data stacks in this env only.
output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}
