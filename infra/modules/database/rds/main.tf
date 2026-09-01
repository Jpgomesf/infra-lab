# AWS implementation of the `database` capability (see ../CONTRACT.md).
# Vanilla PostgreSQL, same as Cloud SQL — the app's DATABASE_URL does not change.

# The AWS answer to the contract's "private connectivity" invariant. Cloud SQL
# reaches privacy through a VPC peering (Private Service Access); RDS reaches it
# by simply living in the private subnets, which is both simpler and cheaper.
resource "aws_db_subnet_group" "this" {
  name        = var.name
  description = "Private subnets for ${var.name}"
  subnet_ids  = var.subnet_ids

  tags = {
    Name = var.name
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-postgres"
  description = "Postgres ingress for ${var.name}"
  vpc_id      = var.network_id

  tags = {
    Name = "${var.name}-postgres"
  }
}

# No egress rules at all: a Postgres instance has no reason to originate
# traffic. Terraform leaves the group with zero egress when none is declared.
resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "Postgres from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "security_group" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "Postgres from ${each.value}"
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.tier

  # COST — db.t4g.micro is the cheapest viable shape (~$12/mo on-demand). It is
  # also the class the *legacy* 12-month AWS free tier covers at 750 hrs/mo,
  # but that offer only applies to accounts created before 2025-07-15. Accounts
  # opened after AWS's July 2025 free-tier overhaul get a credit pool instead,
  # so on a new account this instance is billed from day one. Verified on
  # https://aws.amazon.com/rds/pricing/ and https://aws.amazon.com/free/.

  allocated_storage     = var.disk_size_gb
  max_allocated_storage = var.max_disk_size_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.database_name
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  # Contract invariant: no public IP, reachable only from the private network.
  publicly_accessible = false

  # Contract input `availability_type` -> the only HA knob RDS has.
  multi_az = var.availability_type == "REGIONAL"

  # A non-zero retention is what turns on automated backups AND point-in-time
  # recovery on RDS — there is no separate PITR switch as there is on Cloud SQL.
  backup_retention_period = var.backups_enabled ? var.backup_retention_days : 0
  copy_tags_to_snapshot   = true

  # Disposability parity with the dev Cloud SQL instance: an environment that
  # declares it does not want backups does not get held hostage by a final
  # snapshot on destroy either.
  skip_final_snapshot       = !var.backups_enabled
  final_snapshot_identifier = var.backups_enabled ? "${var.name}-final" : null

  deletion_protection        = var.deletion_protection
  auto_minor_version_upgrade = true

  # Postgres logs to CloudWatch; ~$0.50/GB ingested, negligible for a lab.
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # RDS has no equivalent of Cloud SQL's activation_policy = "NEVER". The AWS
  # cost lever is a manual stop (max 7 days, then it auto-starts) or destroying
  # the stack, which is what infra/envs/aws-dev is designed for.
}
