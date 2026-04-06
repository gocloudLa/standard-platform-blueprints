# Networking — Blueprint specifics

This document describes **networking-specific** details for this blueprint: what it deploys, key parameters, and important operational considerations (TGW sharing, routing, VPN). For general project usage (SSO, Terragrunt, commands), see the blueprint’s [README.md](./README.md) (if present) and the repository root documentation.

## 🎯 Blueprint overview

This blueprint deploys a **network foundation** on the GoCloud Standard Platform (Base layer), focused on:

- **VPC** with public/private subnets across AZs, IGW + NAT.
- **Gateway endpoints** for S3 and DynamoDB.
- **Transit Gateway (TGW)** with VPC attachment(s) and optional **AWS RAM sharing** to another account in the same AWS Organization.
- **Site-to-Site VPN** examples (to a VPC via VGW and to a TGW).
- **Route53 zones** (public + private) and **Cloud Map namespaces** (private DNS) for service discovery.

The blueprint is configured for a lab-style multi-account setup:

- **`lv1` (Lab VPC Net)** in account `511192438786`: creates the VPC and TGW (owner account).
- **`lv2` (Lab VPC Ac1)** in account `377730029539`: companion account for cross-account patterns (e.g., TGW sharing/attachments).

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
  - Public route table default route to **IGW**
  - Private route table default route to **NAT Gateway**
- **NAT**:
  - Single NAT in `public-a` (cost-effective for labs; for production consider multi-AZ NAT).
- **Network ACLs**:
  - Placeholder objects for `public` and `private` (rules empty by default).

### 🧭 VPC endpoints (Gateway)

- **S3 Gateway endpoint** attached to `private` and `public` route tables with an IAM policy from `data.aws_iam_policy_document`.
- **DynamoDB Gateway endpoint** attached similarly.

These reduce NAT/IGW dependency for AWS API access to S3/DynamoDB traffic.

### 🧷 Transit Gateway (TGW)

This blueprint can create a TGW and attach the VPC to it.

Configured highlights (example `tgw-01`):

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

## 🔒 Site-to-Site VPN options

This blueprint includes examples for:

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

- **Public hosted zone**: `local.zone_public` (e.g. `democorp.cloud`)
- **Private hosted zone**: `local.zone_private` (e.g. `democorp.private`) associated to the `networking` VPC

## 🧠 Cloud Map namespaces

Creates private DNS namespaces like:

- `project1.<internal_domain>`
- `project2.<internal_domain>`

Each namespace is associated to the `networking` VPC.

## ⚠️ Operational notes / gotchas

- **TGW RAM sharing requires org enablement**: enabling RAM sharing with AWS Organizations is a console-side org setting. Even if “RAM exists”, shares can still fail until onboarding completes.
- **Blackhole route**: the example TGW route blackholes `0.0.0.0/0`. Keep it only if you explicitly want “drop-all” behavior for that route table.
- **Single NAT**: lab-friendly but is a single-AZ dependency. For production, use one NAT per AZ (or a more deliberate egress architecture).
- **CIDR planning**: ensure VPC CIDRs and on-prem CIDRs do not overlap; TGW routing becomes ambiguous with overlaps.

## 📚 References

- AWS Transit Gateway docs: [Amazon VPC — AWS Transit Gateway](https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html)
- Accept TGW resource share (RAM): [Accept a transit gateway share](https://docs.aws.amazon.com/vpc/latest/tgw/share-accept-tgw.html)
- Terraform TGW module used as reference: [terraform-aws-transit-gateway](https://github.com/terraform-aws-modules/terraform-aws-transit-gateway)
- AWS Site-to-Site VPN overview: [AWS Site-to-Site VPN](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html)
- AWS Private DNS namespaces (Cloud Map): [AWS Cloud Map](https://docs.aws.amazon.com/cloud-map/latest/dg/what-is-cloud-map.html)

---

For Standard Platform and GoCloud support: [www.gocloud.la](https://www.gocloud.la) · info@gocloud.la
