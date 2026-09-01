# network/aws-vpc

AWS implementation of the [`network` capability](../CONTRACT.md): one VPC,
private + public subnets across two AZs in one region, an internet gateway, and
a single NAT gateway for private egress.

## Contract deviations

The contract was written against GCP's model. Three things do not map cleanly,
and this module reports that rather than papering over it.

| Contract field | What happens here | Why |
| --- | --- | --- |
| `subnet_cidr` (input) | becomes the **VPC** CIDR; subnets are sliced out of it | GCP puts the range on the subnet, AWS puts it on the VPC. One CIDR knob, remapped one level up. |
| `subnet_id` (output) | the **primary private subnet** id | The contract field is singular. A comma-joined string would satisfy the type and break every consumer, so the singular field stays singular and honest. EKS reads the `private_subnet_ids` extra instead — a list is genuinely a different shape, not a different spelling. |
| `pods_range_name` / `services_range_name` (outputs) | always `null` | EKS has no secondary ranges. The VPC CNI gives pods real VPC IPs out of the node subnets, and service IPs come from the cluster's own network config. There is nothing to name. |
| `pods_cidr` / `services_cidr` (inputs) | accepted, unused | Same reason. An environment may pass them; they change nothing. |
| `project_id` (input) | accepted, unused | AWS has no project. The account comes from the provider credentials. |

Private connectivity for the database capability is a **DB subnet group** over
`private_subnet_ids` (the contract's own invariant already anticipates this),
not GCP's Private Service Access peering.

## Provider-specific extras

`private_subnet_ids`, `public_subnet_ids`, `vpc_cidr`, `availability_zones`.
Only AWS environments may read these — that restriction is the whole point of
the contract.

## Cost

A NAT gateway bills **~$0.045/hr, ~$32.85/mo** before the ~$0.045/GB
data-processing charge, verified on
[VPC pricing](https://aws.amazon.com/vpc/pricing/). GCP's Cloud NAT has no
comparable hourly floor. This module runs **one** NAT for the whole VPC: an
AZ-level single point of failure, traded for not paying ~$64/mo for two.
