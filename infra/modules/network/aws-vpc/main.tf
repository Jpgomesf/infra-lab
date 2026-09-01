# AWS implementation of the `network` capability (see ../CONTRACT.md).
# Contract deviations are listed in README.md next to this file.

data "aws_availability_zones" "available" {
  state = "available"

  # Local and wavelength zones need an opt-in and cannot host EKS subnets.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.subnet_cidr, var.subnet_newbits, i)]
  public_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.subnet_cidr, var.subnet_newbits, i + var.public_subnet_offset)]
}

resource "aws_vpc" "this" {
  cidr_block = var.subnet_cidr

  # Both are required for EKS: the kubelet resolves the private DNS name of its
  # own instance, and RDS private endpoints are DNS-only.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }

  lifecycle {
    # The private slices take netnums 0..az_count-1 and the public ones
    # public_subnet_offset..+az_count-1, out of the 2^subnet_newbits available.
    # At the defaults (newbits 4, offset 8) that is safe up to 8 AZs and
    # silently overlaps at 9. Fail loudly instead.
    precondition {
      condition     = var.az_count >= 2 && var.az_count <= var.public_subnet_offset && var.public_subnet_offset + var.az_count <= pow(2, var.subnet_newbits)
      error_message = "az_count must be >= 2 (EKS requires two AZs) and small enough that the private slices (0..az_count-1) and public slices (public_subnet_offset..+az_count-1) both fit in the 2^subnet_newbits available netnums without overlapping."
    }
  }
}

# Private subnets hold every workload: nodes, pods (VPC CNI hands out real VPC
# IPs from this range) and the RDS subnet group. No route to the IGW.
resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-${local.azs[count.index]}"
    # How the AWS Load Balancer Controller discovers where to place an
    # internal NLB/ALB. Harmless if the controller is never installed.
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Public subnets exist only to host the NAT gateway and any internet-facing
# load balancer. Nothing runs in them, so auto-assigned public IPs stay off.
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# ---------------------------------------------------------------------------
# NAT: one gateway for the whole VPC.
#
# COST — this is the single biggest AWS-vs-GCP surprise in this repo. A NAT
# gateway bills ~$0.045/hr just to exist, i.e. ~$32/mo before the ~$0.045/GB
# data-processing charge on every byte that crosses it. GCP's Cloud NAT has no
# comparable hourly floor (~$0.0014/hr per assigned VM, so ~$2/mo at this size)
# and charges roughly the same per GB. Nothing in the GCP stack prepares you
# for a $32/mo line item that appears before a single pod starts.
#
# One gateway is a deliberate lab trade-off: it is an AZ-level single point of
# failure, and the HA shape is one NAT per AZ — ~$64/mo for the two AZs EKS
# already forces. Interface VPC endpoints for S3/ECR/logs would cut the
# per-GB half but add ~$7/mo each, so they only pay off under real traffic.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.name}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table, because there is one NAT gateway. Per-AZ NATs would
# need a route table per AZ so that cross-AZ traffic charges do not appear.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# The default security group allows all traffic between its members. Nothing is
# ever placed in it, but leaving it permissive is a standing finding, so it is
# emptied here.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-default-do-not-use"
  }
}
