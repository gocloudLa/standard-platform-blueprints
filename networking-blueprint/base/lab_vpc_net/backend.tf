# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "dmc-sha-tf-backend"
    key            = "511192438786/base-lab_vpc_net/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "dmc-sha-tf-backend"
    encrypt        = true
    profile        = "democorp.cloud-lv1"
    assume_role = {
      role_arn = "arn:aws:iam::112036182825:role/dmc-sha-tf-backend-511192438786"
    }
  }
}
