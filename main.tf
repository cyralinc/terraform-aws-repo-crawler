resource "random_id" "this" {
  byte_length = 8
}

locals {
  function_name             = var.crawler_name != "" ? var.crawler_name : "cyral-repo-crawler-${random_id.this.hex}"
  dynamodb_cache_table_name = "${local.function_name}-${var.dynamodb_cache_table_name_suffix}"
  cyral_secret_arn          = var.cyral_secret_arn != "" ? var.cyral_secret_arn : aws_secretsmanager_secret.cyral_secret[0].arn
  repo_secret_arn           = var.repo_secret_arn != "" ? var.repo_secret_arn : aws_secretsmanager_secret.repo_secret[0].arn
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
  # Allows access to the required secrets in Secrets Manager.
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = [
      local.cyral_secret_arn,
      local.repo_secret_arn,
    ]
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

  # Allows Lambda to create network interfaces. Required to within a VPC.
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  # Allows Lambda to write CloudWatch metrics.
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    effect    = "Allow"
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
      "arn:aws:dynamodb:*:*:table/${local.dynamodb_cache_table_name}"
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

resource "aws_secretsmanager_secret" "repo_secret" {
  count       = var.repo_secret_arn != "" ? 0 : 1
  name        = "/${local.function_name}/RepoSecret"
  description = "Repository credentials (username and password)"
}

resource "aws_secretsmanager_secret_version" "cyral_secret_version" {
  count         = var.cyral_secret_arn != "" ? 0 : 1
  secret_id     = aws_secretsmanager_secret.cyral_secret[0].id
  secret_string = jsonencode({
    client-id     = var.cyral_client_id,
    client-secret = var.cyral_client_secret,
  })
}

resource "aws_secretsmanager_secret_version" "repo_secret_version" {
  count         = var.repo_secret_arn != "" ? 0 : 1
  secret_id     = aws_secretsmanager_secret.repo_secret[0].id
  secret_string = jsonencode({
    username = var.repo_username,
    password = var.repo_password,
  })
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.this.arn
  s3_bucket     = "cyral-public-assets-${data.aws_region.current.name}"
  s3_key        = "cyral-repo-crawler/${var.crawler_version}/cyral-repo-crawler-lambda-${var.crawler_version}.zip"
  timeout       = var.timeout
  runtime       = "go1.x"
  handler       = "crawler-lambda"
  vpc_config {
    security_group_ids = [aws_security_group.this.id]
    subnet_ids         = var.subnet_ids
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

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.function_name}-event-rule"
  description         = "Runs the Repo Crawler Lambda function as specified by the scheduled expression."
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  rule  = aws_cloudwatch_event_rule.this.name
  arn   = aws_lambda_function.this.arn
  input = jsonencode(
    {
      config = {
        repo-name             = var.repo_name,
        repo-type             = var.repo_type,
        repo-host             = var.repo_host,
        repo-port             = var.repo_port,
        repo-database         = var.repo_database,
        repo-sample-size      = var.repo_sample_size,
        repo-max-open-conns   = var.repo_max_open_conns,
        repo-creds-secret-arn = local.repo_secret_arn
        repo-advanced         = {
          snowflake = {
            account   = var.snowflake_account,
            role      = var.snowflake_role,
            warehouse = var.snowflake_warehouse,
          },
          oracle = {
            service-name = var.oracle_service
          },
          connection-string-args = var.connection-string-args
        },
        data-classification = var.enable_data_classification,
        account-discovery   = var.enable_account_discovery,
      }
    }
  )
}

resource "aws_lambda_permission" "this" {
  function_name = aws_lambda_function.this.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
