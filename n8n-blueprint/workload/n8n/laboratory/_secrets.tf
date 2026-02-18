# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

data "aws_ssm_parameter" "terraform" {
  name = "/terraform/${local.common_name}-workload"
}

locals {
  secrets = jsondecode(data.aws_ssm_parameter.terraform.value)
}
