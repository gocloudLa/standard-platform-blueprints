data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "s3_endpoint_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}