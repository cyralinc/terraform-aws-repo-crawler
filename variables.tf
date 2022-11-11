# Cyral Configuration
variable "control_plane_host" {
  type        = string
  description = "The host for the Cyral Control Plane API, e.g. tenant.cyral.com."
}

variable "control_plane_rest_port" {
  type        = number
  description = "The TCP/IP port for the Cyral Control Plane REST API. (default: 443)"
  default     = 443
}

variable "control_plane_grpc_port" {
  type        = number
  description = "The TCP/IP port for the Cyral Control Plane gRPC API (default: 443)."
  default     = 443
}

variable "cyral_secret_arn" {
  type        = string
  description = "ARN of the entry in AWS Secrets Manager that stores the secret containing the credentials for the Cyral API. If empty, cyral_client_id and cyral_client_secret must be provided, and a new secret will be created."
  default     = ""
}

variable "cyral_client_id" {
  type        = string
  description = "The client ID to connect to the Cyral API."
  default     = ""
}

variable "cyral_client_secret" {
  type        = string
  description = "The client secret to connect to the Cyral API."
  default     = ""
}

# Repository configuration

variable "repo_name" {
  type        = string
  description = "The repository name on the Cyral Control Plane."
}

variable "repo_type" {
  type        = string
  description = "The repository type on the Cyral Control Plane."
  validation {
    condition = contains(
      [
        "sqlserver",
        "mysql",
        "postgresql",
        "redshift",
        "denodo",
        "snowflake",
        "oracle",
      ],
      var.repo_type
    )
    error_message = "Invalid repo type."
  }
}

variable "repo_host" {
  type        = string
  description = "The hostname or host address of the database instance."
}

variable "repo_port" {
  type        = number
  description = "The port of the database service in the database instance."
}

variable "repo_secret_arn" {
  type        = string
  description = "ARN of the entry in AWS Secrets Manager that stores the secret containing the credentials to connect to the repository. If empty, repo_username and repo_password must be provided, and a new secret will be created."
  default     = ""
}

variable "repo_username" {
  type        = string
  description = "The username to connect to the repository."
  default     = ""
}

variable "repo_password" {
  type        = string
  description = "The password to connect to the repository."
  default     = ""
}

variable "repo_database" {
  type        = string
  description = "The database on the repository that the repo crawler will connect to."
}

variable "repo_sample_size" {
  type        = number
  description = "Number of rows to sample from each table (default: 5)."
  default     = 5
}

variable "repo_max_open_conns" {
  type        = number
  description = "Maximum number of open connections to the database (default: 10)."
  default     = 10
}

variable "snowflake_account" {
  type        = string
  description = "The Snowflake account. Omit if not configuring a Snowflake repo."
  default     = ""
}

variable "snowflake_role" {
  type        = string
  description = "The Snowflake role. Omit if not configuring a Snowflake repo."
  default     = ""
}

variable "snowflake_warehouse" {
  type        = string
  description = "The Snowflake warehouse. Omit if not configuring a Snowflake repo."
  default     = ""
}

variable "oracle_service" {
  type        = string
  description = "The Oracle service name. Omit if not configuring an Oracle repo."
  default     = ""
}

variable "connection-string-args" {
  type        = list(string)
  description = "Optional database connection string options, in key/value format e.g. opt1=val1, opt2=val2 etc. Omit if not configuring a PostgreSQL-like repo, i.e. Redshift, Denodo, or PostgreSQL."
  default     = []
}

# Lambda and networking configuration
variable "vpc_id" {
  type        = string
  description = "The VPC the lambda will be attached to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The subnets that the Repo Crawler Lambda function will be deployed to. All subnets must be able to reach both the Cyral Control Plane and the database being crawled. These subnets must also support communication with CloudWatch and Secrets Manager."
}

variable "timeout" {
  type        = number
  description = "The timeout of the Repo Crawler Lambda function, in seconds (default: 300)."
  default     = 300
}

variable "crawler_version" {
  type        = string
  description = "The version of the Cyral Repo Crawler to use, e.g. v1.2.3."
}

variable "crawler_name" {
  type        = string
  description = "The name of the Repo Crawler Lambda function. If omitted, it will default to cyral-repo-crawler-<16 character random alphanumeric string>."
  default     = ""
}

variable "dynamodb_cache_table_name_suffix" {
  type        = string
  description = "The suffix for the DynamoDB table name used for the classification cache. The full table will be prefixed with the Lambda function name (default: cyralRepoCrawlerCache)."
  default     = "cyralRepoCrawlerCache"
}

variable "schedule_expression" {
  type        = string
  description = "Schedule expression to invoke the repo crawler (default: every six hours, i.e. cron(0 0/6 * * ? *))."
  default     = "cron(0 0/6 * * ? *)"
  # TODO: validation? -ccampo 2022-11-10
}

variable "enable_data_classification" {
  type        = bool
  description = "Configures the Crawler to run in data classification mode, i.e., sample and classify data according to a set of existing labels (default: true)."
  default     = true
}

variable "enable_account_discovery" {
  type        = bool
  description = "Configures the Crawler to run in account discovery mode, i.e., query and discover all existing user accounts in the database (default: true)."
  default     = true
}
