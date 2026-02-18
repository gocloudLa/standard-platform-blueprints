# =============================================================================
# This file is generated and maintained by GoCloud CLI
# DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "dmc-sha-tf-backend"
    key            = "690282640967/project-n8n-laboratory/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "dmc-sha-tf-backend"
    encrypt        = true
    profile        = "democorp.cloud-lab"
    assume_role = {
      role_arn = "arn:aws:iam::112036182825:role/dmc-sha-tf-backend-690282640967"
    }
  }
}
