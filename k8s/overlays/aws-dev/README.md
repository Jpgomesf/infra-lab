# overlays/aws-dev (stub — the AWS lab)

Mirrors `overlays/dev`, against `infra/envs/aws-dev` instead of the GCP dev
project. When the EKS cluster exists, this overlay will:

- set `images:` to **ECR** repository paths
  (`<account>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>`) — ECR gives 500 MB/mo
  of private storage on the legacy free tier and ~$0.10/GB/mo after
- **not** annotate the `api`/`mcp-server` KSAs at all. This is the one place AWS
  is simpler: GKE Workload Identity needs an
  `iam.gke.io/gcp-service-account` annotation, and IRSA needed
  `eks.amazonaws.com/role-arn`, but **EKS Pod Identity needs neither**. The
  binding lives entirely in `infra/modules/iam/eks-pod-identity` as an
  `aws_eks_pod_identity_association`. The base manifests' ServiceAccounts are
  used verbatim.
- replace the in-cluster `postgres` and `minio` with `ExternalSecret`-fed
  `DATABASE_URL` / bucket config pointing at RDS and S3. The `SecretStore`
  backend is **AWS Secrets Manager**, reached with the same Pod Identity role —
  a backend swap in this overlay, not a change to any base manifest.
  `S3_ENDPOINT` goes away entirely: the AWS SDK resolves its own regional
  endpoint, which is why the `object-store` module returns `null` for it.
- supply its own `Gateway` named `lab` in the `app` namespace, so
  `k8s/base/httproutes.yaml` attaches unchanged. Envoy Gateway installs the same
  way it does on kind — it is a Deployment, not a cloud integration. Its Service
  becomes a `LoadBalancer`, which on EKS means an NLB and needs the AWS Load
  Balancer Controller installed; the public/private subnet
  `kubernetes.io/role/elb` tags the network module already writes are what that
  controller discovers.
- set a `storageClassName` of **`gp3`** on any PVC. EKS's default class is `gp2`
  unless the EBS CSI driver is installed with gp3 as default; gp3 is both faster
  and ~20% cheaper, so it is worth naming explicitly rather than inheriting.
  (GKE's equivalent knob is `standard-rwo` vs `premium-rwo`.)
- replace `otel-lgtm` with an OTel collector Deployment — **export target TBD.**
  The honest options are CloudWatch/X-Ray (native, cheap ingest, weak traces),
  Amazon Managed Prometheus + Managed Grafana (closest to the local experience,
  ~$9/mo for Grafana plus per-sample ingest), or self-hosted LGTM in-cluster
  (free, but then the lab is operating its own observability stack). Undecided
  until the AWS env is actually run. The Service keeps the name `otel-lgtm` and
  port `4317` either way, so no base manifest changes.

Everything above is overlay-local. If something here starts wanting to change a
file in `k8s/base`, that is the layering rule being violated, not an exception.
