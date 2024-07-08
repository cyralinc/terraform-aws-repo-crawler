# Example Deployments

There are a couple of component involved in utilizing the crawler

1. Deploy the module
2. Network Considerations
3. Secrets
4. Data Repo Scan Schedule (Event Bridge Rule)

## Deploy the module

The module deployment itself is pretty simple and will deploy a lambda

```terraform
module "cyral_repo_crawler" {
  source             = "cyralinc/repo-crawler/aws"
  version            = "~> 1.0"
  crawler_version    = "v0.12.4"
  control_plane_host = "example.app.cyral.com"

  # These are optional depending on if you the DB is publically accessible or not
  vpc_id              = "vpc-1234"
  subnet_ids          = ["subnet-1234","subnet-5678"]

  # Create a set of credentials on the control plane
  cyral_client_id     = "sa/default/12345"
  cyral_client_secret = "asdf12345"
  
  # This is used to provide the lambda access to any database secrets to run the crawler.
  repo_secret_arns = [ "arn:aws:secretsmanager:us-east-1:111222333444:secret:/cyral/*" ]
  
}
```

## Network Considerations

In order for the crawler to acess databases that are not internet accessible a VPC and Subnets will need to be provided via the `vpc_id` and `subnet_ids` variables. The Provided subnets will need internet access to communicate with the controlplane.
If the database is internet accessible you can skip the `vpc_id` and `subnet_ids` variables

## Secrets

The Repo Crawler will need access to the database with local credentials which should be stored in a Secret.
To allow the Lambda to access those secrets you'll have to provide the ARN's or a wildcard based value that will allow the lambda to read the secrets to establish connections. Provide the ARN pattern with the `repo_secret_arns` variable shown above.

An example of creating the secrets would look something like this.

``` terraform
locals {
  repo_name           = "dataRepoName
  repo_username       = "dbUsername"
  repo_password       = "thePassword"
}

resource "aws_secretsmanager_secret" "repo_secret" {
  name        = "/cyral/${local.repo_name}/RepoCreds"
  description = "Repository credentials (username and password)"
  recovery_window_in_days = 0 # Use this when testing so it can easily be cleaned up and re-used
}


resource "aws_secretsmanager_secret_version" "repo_secret_version" {
  secret_id     = aws_secretsmanager_secret.repo_secret.id
  secret_string = jsonencode(
    {
      username = local.repo_username,
      password = local.repo_password,
    }
  )
}
```

## Data Repo Scan Schedule (Event Bridge Rule)

In order to create a scheduled scan you'll have to create an event bridge rule with the correct permissions. The following example is fairly straight forward.

```terraform
locals {
  repo_name           = "dataRepoName"
  schedule            = "cron(0 0/6 * * ? *)"
}

# Create the rule trigger/schedule

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.repo_name}-event-rule"
  description         = "Runs the Repo Crawler Lambda function as specified by the scheduled expression."
  schedule_expression = local.schedule
}

# Point the rule at the lambda and provide the configuration

resource "aws_cloudwatch_event_target" "this" {
  rule  = aws_cloudwatch_event_rule.this.name
  arn   = module.cyral_repo_crawler.repo_crawler_lambda_function_arn
  input = jsonencode(
    {
      config = {
        # See the section below for full configuration options
        repo-name              = local.repo_name
        repo-creds-secret-arn  = aws_secretsmanager_secret.repo_secret.arn # See secret in previous section
      }
    }
  )
}

# Allow Event Bridge Rule to invoke the Lambda

resource "aws_lambda_permission" "this" {
  function_name = module.cyral_repo_crawler.repo_crawler_lambda_function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
```

### Full Configuration Options

The only required configuration parameters are the `repo-name` and `repo-creds-secret-arn` however the full selection of configuration options is below. The majority of this information is pulled from the control plane and these config options are overrides. Default values are shown in other cases.

```terraform
resource "aws_cloudwatch_event_target" "this" {
  rule  = aws_cloudwatch_event_rule.this.name
  arn   = aws_lambda_function.this.arn
  input = jsonencode(
    config = {
        repo-name              = "Name of repo to crawl",
        repo-type              = "Override Repo Type",
        repo-host              = "Override Repo Host",
        repo-port              = "Override Repo Port",
        repo-database          = "Specify the DB to scan otherwise all are scanned. (only applicable to some repo types)",
        repo-sample-size       = 5,
        repo-max-query-timeout = "0s",
        repo-max-open-conns    = 10,
        repo-max-parallel-dbs  = 0,
        repo-max-concurrency   = 0,
        repo-include-paths     = "*",
        repo-exclude-paths     = "*",
        repo-creds-secret-arn  = "ARN with credentials to the database"
        repo-advanced = {
            snowflake = {
                account   = "Account Name",
                role      = "Role",
                warehouse = "Warehouse",
            },
            oracle = {
                service-name = "Service name, Typically ORCL"
            },
            connection-string-args = "Additional arguemnts to provide to the connection string"
        },
        data-classification = true,
        account-discovery   = true,
    }
  )
}
```

#### Path Include/Exclude

You can provide an Include or Exclude type approach leveraging the `repo-include-paths` or `repo-exclude-paths` which supports a comma-separated list of glob patterns, in the format `database.schema.table`, which represent paths to include/exclude when crawling the database.

#### Snowflake

If you are going to crawl a snowflake repository you will need to provide the appropriate `repo-advanced` section

#### Oracle

In order to crawl an Oracle repo you'll need to provide the appropriate `repo-advanced` section. Typically the service name is `ORCL`.

#### Crawl Type

By default both a classification and account crawl will happen. Either of these can be disabled if required.
