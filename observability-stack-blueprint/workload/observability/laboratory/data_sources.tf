data "aws_caller_identity" "current" {}

data "aws_lb" "public_alb" {
  name = "${local.common_name_prefix}-core-external-00"
}

data "aws_s3_bucket" "mimir_blocks" {
  bucket = "${local.common_name}-mimir-blocks"
}

data "aws_s3_bucket" "tempo_traces" {
  bucket = "${local.common_name}-tempo-traces"
}

data "aws_s3_bucket" "loki_chunks" {
  bucket = "${local.common_name}-loki-chunks"
}

