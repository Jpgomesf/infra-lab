# Contract output, remapped honestly. Cloud SQL hands out a private IP; RDS
# never exposes one — the instance is reachable only through a DNS name that
# resolves to a private address inside the VPC, and that address changes on
# failover. The name IS the stable handle, so the contract field carries it.
# Consumers build DATABASE_URL from this either way, so nothing downstream cares.
output "private_ip" {
  description = "Contract output. The instance's private DNS address (RDS has no stable private IP)."
  value       = aws_db_instance.this.address
}

# Contract output flagged as a provider-specific extra ("envs must not require
# it"). On GCP it is the Cloud SQL connector handle; here it is host:port.
output "connection_name" {
  description = "Contract output (provider-specific extra). address:port."
  value       = aws_db_instance.this.endpoint
}

output "database_name" {
  description = "Contract output."
  value       = aws_db_instance.this.db_name
}

# ---- Provider-specific extras -----------------------------------------------

output "port" {
  description = "Extra. Postgres port."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Extra. The instance's security group, for adding ingress sources later."
  value       = aws_security_group.this.id
}
