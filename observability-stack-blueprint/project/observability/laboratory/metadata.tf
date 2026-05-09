# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

locals {

  metadata = {
    aws_region  = "us-east-2"
    environment = "Laboratory"
    project     = "Observability"

    internal_domain = "democorp.internal"
    private_domain  = "democorp.private"
    public_domain   = "democorp.cloud"

    key = {
      company = "dmc"
      region  = "use2"
      env     = "lab"
      project = "obs"
      layer   = "project"
    }
  }

  common_name_prefix = join("-", [
    local.metadata.key.company,
    local.metadata.key.env
  ])

  common_name = join("-", [
    local.common_name_prefix,
    local.metadata.key.project
  ])

}
