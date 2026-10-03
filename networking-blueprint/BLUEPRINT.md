# Networking — Blueprint specifics

This document describes **networking-specific** details for this blueprint: what it deploys, key parameters, and important operational considerations (TGW sharing and routing). For general project usage (SSO, Terragrunt, commands), see the blueprint’s [README.md](./README.md) and the repository root documentation.

## 🎯 Blueprint overview

This blueprint deploys a **network foundation** on the GoCloud Standard Platform (Base layer), focused on:

- **VPC** with public/private subnets across AZs, IGW, and NAT.
- **Gateway endpoints** for S3 and DynamoDB.
- **Transit Gateway** created in `lab_vpc_net`, shared with RAM, and attached to the `networking` VPC.
- **Route53 zones** (public + private) and **Cloud Map namespaces** on `lab_vpc_net`.

Commented blocks in the same `main.tf` files are optional examples. Uncomment one to try it:

- **Peering** in both stacks (same-account on `lab_vpc_ac1`, cross-account across both).
- **TGW attachment** of `production` on `lab_vpc_ac1` (`create_tgw = false`).
- **Site-to-Site VPN** on `lab_vpc_net` (`vpn-vpc` via a virtual private gateway, and `vpn-tgw`).

The blueprint is a lab-style multi-account setup:

- **`lv1` (Lab VPC Net)** in account `511192438786`: VPC `networking` (`10.20.0.0/16`) and the TGW owner.
- **`lv2` (Lab VPC Ac1)** in account `377730029539`: VPCs `production` (`10.30.0.0/16`) and `development` (`10.40.0.0/16`). The TGW attachment stays commented until you want this account on the shared gateway.

Environments/accounts are defined in `gocloud.yaml`.

## 📋 Platform prerequisites

This blueprint assumes you already have:

- **AWS Organizations** in place for your multi-account setup (recommended).
- **AWS SSO / IAM Identity Center** configured (as per `gocloud.yaml`), or equivalent access.
- A working **Terraform/OpenTofu + Terragrunt** workflow (the repo uses Standard Platform modules).

If you plan to use **TGW sharing**:

- **AWS RAM sharing with AWS Organizations must be enabled** in the Organization management account (see “TGW sharing (RAM) notes” below). Without this, RAM will reject the association with `OperationNotPermittedException`.

## 🧩 What the Base layer configures (lab_vpc_net)

The main configuration lives in `base/lab_vpc_net/main.tf` and uses Standard Platform `modules/base` parameters.

### 🌐 VPC

Key components:

- **CIDR**: `local.vpc_cidr` (see `locals.tf`).
- **Subnets**:
  - `public-{a,b,c}`
  - `private-{a,b,c}`
- **Routing**:
  - Public route table default route to the **IGW**
  - Private route table default route to the **EC2 NAT** (`network_interface = "natgw"`). The managed NAT alternative (`kind = "aws"` and `nat_gateway = "natgw"`) is commented next to it.
- **NAT**:
  - Single EC2 NAT in `public-a` (cost-effective for labs; for production consider one NAT per AZ).
- **Network ACLs**:
  - Placeholder objects for `public` and `private` (rules empty by default).

### 🧭 VPC endpoints (Gateway)

- **S3 Gateway endpoint** attached to `private` and `public` route tables with an IAM policy from `data.aws_iam_policy_document`.
- **DynamoDB Gateway endpoint** attached similarly.

These reduce NAT/IGW dependency for AWS API access to S3/DynamoDB traffic.

`base/lab_vpc_ac1/main.tf` uses the same subnet layout on two VPCs. `production` uses a managed NAT (`kind = "aws"`). `development` uses an EC2 NAT, the same pattern as `lab_vpc_net`, and has no gateway endpoints.

### 🧷 Transit Gateway (TGW)

`lab_vpc_net` creates `tgw-01` and attaches the `networking` VPC. `lab_vpc_ac1` does not create a TGW; its attachment block is commented.

Configured highlights:

- **Amazon-side ASN** set (e.g. `64512`).
- **Share TGW with RAM** (`share_tgw = true`) to principals in another account.
- **Auto-accept shared attachments** (`enable_auto_accept_shared_attachments = true`) for smoother cross-account attachments.
- **VPC attachments**:
  - Attaches the `networking` VPC using **private subnets** (`private-a/b/c`).
  - Enables TGW attachment DNS support.
- **TGW route examples**:
  - Adds a static TGW route to `10.20.0.0/16`
  - Adds a blackhole route for `0.0.0.0/0` (use with care; it intentionally drops traffic to that destination on the TGW route table).

### 🔐 TGW sharing (RAM) notes (important)

If you see errors like:

- `OperationNotPermittedException: The resource you are attempting to share can only be shared within your AWS Organization...`

Typical causes:

- **Sharing with AWS Organizations is not enabled in AWS RAM** (Organization onboarding not done).
- The target principal account is **not** in the same Organization (or is suspended/removed).
- An **SCP** blocks `ram:AssociateResourceShare` or related RAM actions.

AWS documentation for accepting TGW shares (console flow): [Accept a transit gateway share](https://docs.aws.amazon.com/vpc/latest/tgw/share-accept-tgw.html).

Terraform reference module this wrapper is based on:

- `terraform-aws-modules/transit-gateway/aws`: [terraform-aws-transit-gateway](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway)

## 🔗 Optional peering

Both `peering_parameters` blocks are commented.

- **Same account** (`lab_vpc_ac1`, key `prd-with-dev`): peer `production` with `development`.
- **Cross account**: `lab_vpc_net` creates the peering toward `development` (`10.40.0.0/16`, account `377730029539`). `lab_vpc_ac1` accepts it (`create_peer = false`) after that peering exists. Replace `vpc_accepter_id` and `peering_id` with the IDs from the first apply.

## 🔒 Site-to-Site VPN options

`vpn_parameters` in `base/lab_vpc_net/main.tf` is commented. The example includes:

- **VPC VPN** (`vpn-vpc`): using a **Virtual Private Gateway (VGW)** attached to the VPC, plus a Customer Gateway with your on-prem public IP.
- **TGW VPN** (`vpn-tgw`): attaching a VPN connection to the Transit Gateway instead of the VPC.

Both examples show:

- `static_routes_only = true`
- Example CIDRs for local/remote networks
- Example route propagation into specific VPC route tables (`route_table_keys`)
- Example CloudWatch tunnel logs enabled

You must replace placeholder values like:

- Customer gateway `ip_address`
- Pre-shared keys
- On-prem CIDR blocks

## 🌐 Route53 zones

The base layer creates:

- **Public hosted zone**: `local.zone_public` (`lv1.democorp.cloud`, because this environment is not `prd`)
- **Private hosted zone**: `local.zone_private` (`lv1.democorp.private`) associated to the `networking` VPC

## 🧠 Cloud Map namespaces

Creates private DNS namespaces like:

- `project1.<internal_domain>`
- `project2.<internal_domain>`

Each namespace is associated to the `networking` VPC.

## ⚠️ Operational notes / gotchas

- **TGW RAM sharing requires org enablement**: enabling RAM sharing with AWS Organizations is a console-side org setting. Even if “RAM exists”, shares can still fail until onboarding completes.
- **Blackhole route**: the example TGW route blackholes `0.0.0.0/0`. Keep it only if you explicitly want “drop-all” behavior for that route table.
- **Single NAT**: `lab_vpc_net` and `development` use one EC2 NAT in `public-a`. That is a single-AZ dependency. For production, use one NAT per AZ.
- **CIDR planning**: ensure VPC CIDRs and on-prem CIDRs do not overlap; TGW routing becomes ambiguous with overlaps.

## 📚 References

- AWS Transit Gateway docs: [Amazon VPC — AWS Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html)
- Accept TGW resource share (RAM): [Accept a transit gateway share](https://docs.aws.amazon.com/vpc/latest/tgw/share-accept-tgw.html)
- Terraform TGW module used as reference: [terraform-aws-transit-gateway](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway)
- AWS Site-to-Site VPN overview: [AWS Site-to-Site VPN](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html)
- AWS Private DNS namespaces (Cloud Map): [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/latest/dg/what-is-cloud-map.html)

---

For Standard Platform and GoCloud support: [www.gocloud.la](https://www.gocloud.la) · info@gocloud.la
