/**
 * # Cyral Repo Crawler AWS module for Terraform
 *
 * This is a Terraform module to install the Cyral Repo Crawler as an AWS
 * Lambda function, including all of its dependencies such as IAM permissions,
 * a DynamoDB cache, etc.
 *
 * See the [examples](./examples) for usage details.
 */

resource "random_id" "this" {
  byte_length = 8
}

locals {
  function_name             = var.crawler_name != "" ? var.crawler_name : "cyral-repo-crawler-${random_id.this.hex}"
  dynamodb_cache_table_name = "${local.function_name}-${var.dynamodb_cache_table_name_suffix}"
  cyral_secret_arn          = var.cyral_secret_arn != "" ? var.cyral_secret_arn : aws_secretsmanager_secret.cyral_secret[0].arn
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution_policy" {
  # Allows access to the necessary secrets in Secrets Manager.
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = concat([local.cyral_secret_arn],var.repo_secret_arns)
  }

  # Allows access to write CloudWatch logs.
  statement {
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
    ]
    effect    = "Allow"
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  # Allows Lambda to create network interfaces.
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
    ]
    effect    = "Allow"
    # These actions don't support resource-level permissions, so we must use
    # "*". See: https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
    resources = ["*"]
  }

  # Allows Lambda to write CloudWatch metrics.
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    effect    = "Allow"
    # This action doesn't support resource-level permissions, so we must use
    # "*". See: https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazoncloudwatch.html
    resources = ["*"]
  }

  # Allows Lambda to read/write from the DynamoDB cache table.
  statement {
    actions = [
      "dynamodb:BatchGet*",
      "dynamodb:DescribeStream",
      "dynamodb:DescribeTable",
      "dynamodb:Get*",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWrite*",
      "dynamodb:CreateTable",
      "dynamodb:Delete*",
      "dynamodb:Update*",
      "dynamodb:PutItem",
    ]
    effect    = "Allow"
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_cache_table_name}"
    ]
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.function_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  inline_policy {
    name   = "${local.function_name}-execution-policy"
    policy = data.aws_iam_policy_document.execution_policy.json
  }
}

resource "aws_security_group" "this" {
  count = length(var.vpc_id) > 0 ? 1 : 0
  name        = local.function_name
  description = "Cyral Repo Crawler security group"
  vpc_id      = var.vpc_id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # All protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_secretsmanager_secret" "cyral_secret" {
  count       = var.cyral_secret_arn != "" ? 0 : 1
  name        = "/${local.function_name}/CyralSecret"
  description = "Cyral API credentials (client ID and secret)"
}



resource "aws_secretsmanager_secret_version" "cyral_secret_version" {
  count         = var.cyral_secret_arn != "" ? 0 : 1
  secret_id     = aws_secretsmanager_secret.cyral_secret[0].id
  secret_string = jsonencode(
    {
      client-id     = var.cyral_client_id,
      client-secret = var.cyral_client_secret,
    }
  )
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.this.arn
  s3_bucket     = "cyral-public-assets-${data.aws_region.current.name}"
  s3_key        = "cyral-repo-crawler/${var.crawler_version}/cyral-repo-crawler-lambda-${var.crawler_version}.zip"
  timeout       = var.timeout
  runtime       = "provided.al2"
  handler       = "bootstrap"

  dynamic vpc_config {
    for_each = length(var.vpc_id) > 0 ? [1] : []
    content {
      security_group_ids = [aws_security_group.this[0].id]
      subnet_ids         = var.subnet_ids
    }
  }

  environment {
    variables = {
      REPO_CRAWLER_CYRAL_WORKER_ID           = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.function_name}"
      REPO_CRAWLER_CYRAL_CREDS_SECRET_ARN    = local.cyral_secret_arn
      REPO_CRAWLER_CYRAL_API_HOST            = var.control_plane_host
      REPO_CRAWLER_CYRAL_API_REST_PORT       = var.control_plane_rest_port
      REPO_CRAWLER_CYRAL_API_GRPC_PORT       = var.control_plane_grpc_port
      REPO_CRAWLER_CACHE_TYPE                = "dynamodb"
      REPO_CRAWLER_CACHE_DYNAMODB_TABLE_NAME = local.dynamodb_cache_table_name
    }
  }
}

resource "aws_dynamodb_table" "this" {
  name         = local.dynamodb_cache_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"

  attribute {
    name = "PK"
    type = "S"
  }
}

