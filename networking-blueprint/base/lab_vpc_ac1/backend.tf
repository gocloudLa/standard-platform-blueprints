# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "dmc-sha-tf-backend"
    key            = "377730029539/base-lab_vpc_ac1/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "dmc-sha-tf-backend"
    encrypt        = true
    profile        = "democorp.cloud-lv2"
    assume_role = {
      role_arn = "arn:aws:iam::112036182825:role/dmc-sha-tf-backend-377730029539"
    }
  }
}
