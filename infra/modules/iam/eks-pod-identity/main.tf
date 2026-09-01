# AWS implementation of the `iam` capability (see ../CONTRACT.md), using EKS Pod
# Identity — the mechanism that replaced IRSA. The portable side of the contract
# is unchanged: apps only ever know their Kubernetes ServiceAccount.
#
# The one thing that gets *better* on this side: GKE Workload Identity needs an
# `iam.gke.io/gcp-service-account` annotation on the KSA, so the k8s manifests
# carry a GCP-shaped string. Pod Identity needs no annotation at all — the
# binding lives entirely in this module. k8s/base stays cloud-agnostic.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    # TagSession is not optional: EKS stamps the session with cluster,
    # namespace and service-account tags, and the AssumeRole call fails without
    # permission to set them.
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = var.name
  }
}

# Contract's `roles` list. See the variable description for why these are policy
# ARNs on AWS and role names on GCP.
resource "aws_iam_role_policy_attachment" "roles" {
  for_each = toset(var.roles)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json != null ? 1 : 0

  name   = "${var.name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

# The binding itself. Short-lived credentials only — no key is ever minted, in
# line with the contract's "no long-lived keys. Ever."
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.ksa_name
  role_arn        = aws_iam_role.this.arn
}
