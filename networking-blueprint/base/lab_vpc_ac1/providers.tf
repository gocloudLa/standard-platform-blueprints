# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================


provider "aws" {
  region  = "${local.metadata.aws_region}"
  profile = "democorp.cloud-lv2"
}

provider "aws" {
  region  = "us-east-1"
  alias   = "use1"
  profile = "democorp.cloud-lv2"
}

