# n8n — Blueprint specifics

This document describes **n8n-specific** details for this blueprint: requirements, secrets, environment variables, and architecture decisions. For general project usage (SSO, Terragrunt, commands), see the blueprint’s [README.md](./README.md).

## 🎯 Blueprint overview

This blueprint deploys **n8n** on the GoCloud Standard Platform with:

- **Project layer**: ECS cluster (Fargate Spot), RDS PostgreSQL 18, EFS with access point for n8n data, and (if applicable) shared ALB.
- **Workload layer**: ECS service running the official image `docker.n8n.io/n8nio/n8n`, with EFS persistence and RDS as the database.

The setup is aimed at a **laboratory-style** environment (e.g. a single `lab` environment). For production or high availability, consider instance size, replicas, backups, and optionally multiple ECS tasks behind the ALB.

## 📋 Platform prerequisites

This blueprint **does not generate** Base or Foundation layers. The account is expected to already have (or you provision elsewhere):

- **VPC** and subnets (public/private).
- **ALB** with HTTPS listener and ACM certificate (the workload registers a target group and host-based rules).
- **Route53** (public zone) for n8n DNS (e.g. `n8n.<domain>`).

In `gocloud.yaml`, `base` and `foundation` layers are set to `false`; only **project** and **workload** are generated for the `n8n` project in the `lab` environment.

## 🔐 Required secrets

Secrets are read from **AWS SSM Parameter Store** (JSON) per layer. You must create the parameters and populate the keys before apply.

### Project layer

- **SSM parameter**: `/terraform/<common_name>-project`
- **Key**:
  - `rds_n8n_password`: password for the PostgreSQL user `n8n` created by the module (DB management). Must be strong and match what the workload uses.

### Workload layer

- **SSM parameter**: `/terraform/<common_name>-workload`
- **Keys**:
  - `n8n_db_postgresdb_password`: password n8n uses to connect to PostgreSQL (must match the `n8n` user in RDS; typically the same as `rds_n8n_password`).
  - `n8n_encryption_key`: encryption key for credentials stored by n8n (recommended 32 characters; see [n8n encryption key](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/)).

Example workload parameter value (JSON):

```json
{
  "n8n_db_postgresdb_password": "your-secure-rds-password",
  "n8n_encryption_key": "a-32-char-random-encryption-key!!"
}
```

You can use `gocloud secrets set` / `gocloud secrets edit` if the CLI is configured for that path.

## 🗄️ Database (RDS)

- **Engine**: PostgreSQL 18.
- **Database**: `n8n`.
- **User**: `n8n` (created by the project module via DB management).
- **Schema**: `public`.
- The container connection uses **SSL** (`DB_POSTGRESDB_SSL=true`, `DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false` for RDS).
- Host and port are read from the Secrets Manager secret created by the RDS module: `rds-<common_name>-pgsql-00`.

## 📁 EFS persistence

- **EFS access point**: `n8n_data`, path `/n8n_data`, permissions 777, UID/GID 1000 (default n8n container user).
- In the ECS service, the EFS volume is mounted at **`/home/node/.n8n`** inside the container (n8n’s default data directory).
- Workflows and local data persist across task restarts.

## 🌐 Relevant environment variables (container)

| Variable | Purpose |
|----------|---------|
| `DB_TYPE` | `postgresdb` |
| `DB_POSTGRESDB_*` | Host, port, database, user, schema, SSL (password via `map_secrets`) |
| `GENERIC_TIMEZONE` | Timezone (e.g. `America/Argentina/Buenos_Aires`) |
| `N8N_HOST` / `N8N_PORT` / `N8N_PROTOCOL` | Public URL and internal port (5678) |
| `N8N_EDITOR_BASE_URL` / `WEBHOOK_URL` | HTTPS URLs for editor and webhooks |
| `N8N_PROXY_HOPS` | `1` (behind proxy/ALB) |
| `N8N_LOG_LEVEL` | `info` (configurable) |
| `N8N_ENCRYPTION_KEY` | Injected from secrets |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS` | `false` (container/EFS environment) |

Official variable documentation: [n8n - Environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/).

## 🔗 ALB and DNS

- The ECS service registers in a **target group** attached to an existing ALB (`alb_name` in the blueprint, e.g. `dmc-lab-core-external-00`).
- **443** listener, **host**-based rule (e.g. `n8n.<domain>`).
- A public **DNS record** is created for that host (Route53, public zone).

Ensure the ALB and zone exist in your account; the ALB name and zone are derived from `metadata` / `common_name` in the project.

## 📚 References

- [n8n - Supported databases](https://docs.n8n.io/hosting/configuration/supported-databases-settings/)
- [n8n - Encryption key](https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/)
- [n8n - Environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [n8n - Deployment (N8N_HOST, proxy)](https://docs.n8n.io/hosting/configuration/environment-variables/deployment/)
- Official image: [docker.n8n.io/n8nio/n8n](https://hub.docker.com/r/n8nio/n8n)

---

For Standard Platform and GoCloud support: [www.gocloud.la](https://www.gocloud.la) · info@gocloud.la
