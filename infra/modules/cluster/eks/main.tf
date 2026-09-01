# AWS implementation of the `cluster` capability (see ../CONTRACT.md).
#
# COST — the asymmetry that decides whether this env runs at all:
#   EKS control plane   $0.10/hr, ~$73/mo, and there is NO free-tier credit.
#                       (Extended support, once a version ages out of the
#                       14-month standard window, is $0.60/hr — 6x.)
#   GKE control plane   $0.10/hr too, but Google grants a $74.40/mo credit that
#                       covers exactly one zonal cluster, so the dev cluster's
#                       control plane is effectively free.
# Same list price, opposite bill. Add the ~$32.85/mo NAT gateway from the
# network module and an idle AWS lab starts at ~$106/mo before a single node.
# Run this env as apply-then-destroy sessions; see infra/envs/aws-dev/README.md.

locals {
  # EKS requires >= 2 subnets in >= 2 AZs. The contract only carries one subnet
  # id, so the AWS extra wins when present and the contract field is the
  # fallback (which EKS will reject — deliberately loud rather than silent).
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : [var.subnetwork]
}

# ---------------------------------------------------------------------------
# Control-plane IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# Envelope encryption with a customer-managed key — opt-in, off by default.
#
# Both clouds already encrypt control-plane data with a provider-owned key out
# of the box. GKE does it for etcd; EKS envelope-encrypts *all* Kubernetes API
# data with an AWS-owned key on every cluster running 1.28+, free and with no
# configuration ("you don't have to take any action" — AWS). So a CMK here buys
# key ownership and CloudTrail visibility, not encryption.
#
# It also buys a sharp edge that matters in an apply-then-destroy lab: AWS is
# explicit that deleting the key degrades the cluster "beyond recovery", and a
# key scheduled for deletion keeps billing through its window. Hence the default
# of false, and hence the resulting scanner finding is registered in
# .trivyignore.yaml rather than bought off with a key nobody needs.
# https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# EKS creates a grant on the key in order to use it, which the default key
# policy does not permit for the cluster role. Without this the cluster fails
# to create.
data "aws_iam_policy_document" "secrets_key" {
  count = var.enable_secrets_encryption ? 1 : 0

  statement {
    sid       = "AccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "ClusterRoleUse"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ListGrants",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster.arn]
    }
  }
}

resource "aws_kms_key" "secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  description             = "${var.name} EKS API data envelope encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.secrets_key[0].json
}

resource "aws_kms_alias" "secrets" {
  count = var.enable_secrets_encryption ? 1 : 0

  name          = "alias/${var.name}-eks-api-data"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# EKS creates this log group implicitly with never-expire retention. Owning it
# here caps retention (and therefore the CloudWatch Logs storage bill).
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cluster_log_retention_days
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  # Contract input, native since AWS provider v6.11.0.
  deletion_protection = var.deletion_protection

  vpc_config {
    subnet_ids = local.subnet_ids

    # Mirrors the GKE posture exactly: private nodes, and a public control-plane
    # endpoint that is reachable only from `authorized_networks`. The private
    # endpoint is on as well so in-VPC traffic never leaves the VPC.
    # Set enable_public_endpoint = false for a VPC-only control plane, which
    # needs a bastion or VPN to administer.
    endpoint_private_access = true
    endpoint_public_access  = var.enable_public_endpoint

    # null (empty list) leaves EKS's own default of 0.0.0.0/0. Same trade-off,
    # and same accepted finding, as the GKE module's master authorized networks:
    # the only CIDR that belongs here is a personal IP, which must not be
    # committed. See .trivyignore.yaml.
    public_access_cidrs = var.enable_public_endpoint && length(var.authorized_networks) > 0 ? var.authorized_networks : null
  }

  # API-only auth. aws-auth ConfigMap management is the legacy path; access
  # entries are the supported one and are what the Pod Identity story assumes.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  dynamic "encryption_config" {
    for_each = var.enable_secrets_encryption ? [1] : []
    content {
      resources = ["secrets"]
      provider {
        key_arn = aws_kms_key.secrets[0].arn
      }
    }
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ---------------------------------------------------------------------------
# Node IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Node groups — one Spot, one optional on-demand, mirroring the GKE pools.
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "spot"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids

  # SPOT on EKS is a managed node group backed by a Spot ASG: ~70% off
  # on-demand, with a 2-minute interruption notice (GKE Spot gives ~30s).
  capacity_type  = "SPOT"
  instance_types = [var.spot_machine_type]
  ami_type       = var.node_ami_type
  disk_size      = var.node_disk_size_gb

  # Contract's autoscaling bounds. EKS managed node groups do not autoscale on
  # their own — min/max here are the ASG bounds that Cluster Autoscaler or
  # Karpenter drives. Without one of those installed, the group sits at
  # desired_size. GKE's node pool autoscaler is built in; this is not.
  scaling_config {
    min_size     = var.spot_min_nodes
    max_size     = var.spot_max_nodes
    desired_size = var.spot_min_nodes
  }

  labels = {
    pool = "spot"
  }

  update_config {
    max_unavailable = 1
  }

  lifecycle {
    # Cluster Autoscaler / Karpenter own desired_size after creation.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

resource "aws_eks_node_group" "on_demand" {
  count = var.on_demand_nodes > 0 ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "on-demand"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = [var.on_demand_machine_type]
  ami_type       = var.node_ami_type
  disk_size      = var.node_disk_size_gb

  scaling_config {
    min_size     = var.on_demand_nodes
    max_size     = var.on_demand_nodes
    desired_size = var.on_demand_nodes
  }

  labels = {
    pool = "on-demand"
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ---------------------------------------------------------------------------
# Pod identity
#
# EKS Pod Identity (2023-11) is the modern mechanism and the one this repo uses:
# a DaemonSet agent hands pods short-lived credentials for a role bound to their
# ServiceAccount. It replaces IRSA's OIDC-provider plumbing — no
# aws_iam_openid_connect_provider, and no annotation on the KSA, which is why
# k8s/base needs no AWS-specific edits at all.
# ---------------------------------------------------------------------------

resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # The agent is a DaemonSet; it has nowhere to run until a node group exists.
  depends_on = [aws_eks_node_group.spot]
}
