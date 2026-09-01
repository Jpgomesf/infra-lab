output "network_id" {
  description = "Contract output. The VPC id."
  value       = aws_vpc.this.id
}

# Contract output. The contract is singular, so this is the primary private
# subnet — the one an implementation that genuinely only needs one would use
# (a single VM, a single ENI). EKS needs at least two AZs and consumes
# `private_subnet_ids` below instead. The contract field is honored, not faked.
output "subnet_id" {
  description = "Contract output. Primary private subnet id."
  value       = aws_subnet.private[0].id
}

# Contract outputs, deliberately null: EKS has no secondary-range concept. The
# VPC CNI allocates pod IPs directly from the node subnets, and service IPs come
# from the cluster's own kubernetes_network_config CIDR, not from the VPC. An
# environment that reads these gets null rather than a name that means nothing.
output "pods_range_name" {
  description = "Contract output. Always null on AWS — EKS has no secondary ranges."
  value       = null
}

output "services_range_name" {
  description = "Contract output. Always null on AWS — EKS has no secondary ranges."
  value       = null
}

# ---- Provider-specific extras (environments may use them only in AWS envs) ---

output "private_subnet_ids" {
  description = "Extra. All private subnet ids; EKS and the RDS subnet group need the full multi-AZ list."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Extra. Public subnet ids, for internet-facing load balancers."
  value       = aws_subnet.public[*].id
}

output "vpc_cidr" {
  description = "Extra. The VPC range, used as the default ingress source for in-VPC security groups."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Extra. The AZs the subnets landed in."
  value       = local.azs
}
