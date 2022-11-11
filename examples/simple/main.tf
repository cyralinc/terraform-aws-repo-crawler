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
  source             = "cyralinc/repo-crawler/aws" # TODO: should we use a different name? -ccampo 2022-11-10
  version            "
  crawler_version    = "v0.5.1"
  control_plane_host = "example.cyral.com"
  repo_type          = "sqlserver"
  repo_name          = "sqlserver-example"
  repo_host          = "sqlserver.example.com"
  repo_port          = 1433
  repo_database      = "exampledb"
  subnet_ids         = ["subnet-example"]
  vpc_id             = "vpc-example"

  # It is preferable to create your own secrets and pass them via the
  # cyral_secret_arn and repo_secret_arn variables. This will allow you to
  # avoid passing confidential values directly in the Terraform config.
  cyral_client_id     = "example_client_id"
  cyral_client_secret = "exampleClientSecret"
  repo_username       = "exampoeRepoUsername"
  repo_password       = "exampoeRepoUsername"
}
