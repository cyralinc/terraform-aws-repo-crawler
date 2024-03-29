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
  source             = "cyralinc/repo-crawler/aws"
  version            = "~> 0.1"
  crawler_version    = "v0.11.1"
  control_plane_host = "example.cyral.com"
  repo_type          = "oracle"
  repo_name          = "oracle-example"
  repo_host          = "oracle.example.com"
  repo_port          = 1521
  repo_database      = "exampledb"
  subnet_ids         = ["subnet-example"]
  vpc_id             = "vpc-example"
  oracle_service     = "XE"

  # It is preferable to create your own secrets and pass them via the
  # cyral_secret_arn and repo_secret_arn variables. This will allow you to
  # avoid passing confidential values directly in the Terraform config.
  cyral_client_id     = "example_client_id"
  cyral_client_secret = "exampleClientSecret"
  repo_username       = "exampleRepoUsername"
  repo_password       = "exampleRepoUsername"
}
