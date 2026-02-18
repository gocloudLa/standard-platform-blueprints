# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["${local.common_name_prefix}"]
  }
}

data "aws_acm_certificate" "this" {
  provider = aws.use1

  domain      = local.zone_public
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# DATABASE
data "aws_secretsmanager_secret" "database_connection" {
  name = "rds-${local.common_name}-pgsql-00"
}
data "aws_secretsmanager_secret_version" "database_connection" {
  secret_id = data.aws_secretsmanager_secret.database_connection.id
}
# "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["username"]}"
# "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["password"]}"
# "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["host"]}"
# "${jsondecode(data.aws_secretsmanager_secret_version.database_connection.secret_string)["port"]}"

