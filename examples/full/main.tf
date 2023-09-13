terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

module "cyral_repo_crawler" {
  source                           = "cyralinc/repo-crawler/aws"
  version                          = "~> 0.1"
  crawler_version                  = "v0.9.3"
  crawler_name                     = "cyral-repo-crawler"
  control_plane_host               = "example.cyral.com"
  control_plane_rest_port          = 443
  control_plane_grpc_port          = 443
  repo_type                        = "sqlserver"
  repo_name                        = "sqlserver-example"
  repo_host                        = "sqlserver.example.com"
  repo_port                        = 1433
  repo_database                    = "exampledb"
  repo_sample_size                 = 5
  repo_max_open_conns              = 10
  subnet_ids                       = ["subnet-example"]
  vpc_id                           = "vpc-example"
  timeout                          = 300
  schedule_expression              = "cron(0 0/6 * * ? *)"
  dynamodb_cache_table_name_suffix = "cyralRepoCrawlerCache"
  enable_data_classification       = true
  enable_account_discovery         = true

  # It is preferable to create your own secrets and pass them via the
  # cyral_secret_arn and repo_secret_arn variables. This will allow you to
  # avoid passing confidential values directly in the Terraform config.
  cyral_client_id     = "example_client_id"
  cyral_client_secret = "exampleClientSecret"
  repo_username       = "exampleRepoUsername"
  repo_password       = "exampleRepoUsername"
  # Prefer to use these instead of the client ID/secret/username/password above
  #cyral_secret_arn    = "arn:aws:secretsmanager:us-east-2:123456789012:secret:/cyral-repo-crawler-37b68aab3a5e55ad/CyralSecret-qwAGUT"
  #repo_secret_arn     = "arn:aws:secretsmanager:us-east-2:123456789012:secret:/cyral-repo-crawler-37b68aab3a5e55ad/RepoSecret-MovNKP"
}
