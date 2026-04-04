# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

locals {

  metadata = {
    aws_region  = "us-east-2"
    environment = "Lab VPC Ac1"

    private_domain = "democorp"
    public_domain  = "democorp.cloud"

    key = {
      company = "dmc"
      region  = "use2"
      env     = "lv2"
      layer   = "base"
    }
  }

  common_name_prefix = join("-", [
    local.metadata.key.company,
    local.metadata.key.env
  ])

  common_name = local.common_name_prefix

}
