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
  description = <<EOF
    ARN of the entry in AWS Secrets Manager that stores the secret containing
    the credentials for the Cyral API. Either this OR the `cyral_client_id` and
    `cyral_client_secret` variables are REQUIRED. If empty, the
    `cyral_client_id` and `cyral_client_secret` variables MUST both be
    provided, and a new secret will be created in AWS Secrets Manager.
  EOF
  default     = ""
}

variable "cyral_client_id" {
  type        = string
  description = <<EOF
    The client ID to connect to the Cyral API. This is REQUIRED if the
    `cyral_secret_arn` variable is empty.
  EOF
  default     = ""
}

variable "cyral_client_secret" {
  type        = string
  description = <<EOF
    The client secret to connect to the Cyral API. This is REQUIRED if the
    `cyral_secret_arn` variable is empty.
  EOF
  default     = ""
  sensitive   = true
}

# Repository configuration

variable "repo_name" {
  type        = string
  description = "The repository name on the Cyral Control Plane."
}

variable "repo_type" {
  type        = string
  description = <<EOF
    The repository type on the Cyral Control Plane. If omitted, the value will
    be inferred from the Control Plane (crawler versions >= v0.9.0 only).
  EOF
  default     = ""
  validation {
    condition = contains(
      [
        "",
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
  description = <<EOF
    The hostname or host address of the database instance. If omitted, the value will
    be inferred from the Control Plane (crawler versions >= v0.9.0 only).
  EOF
  default = ""
}

variable "repo_port" {
  type        = number
  description = <<EOF
    The port of the database service in the database instance. If omitted, the value
    will be inferred from the Control Plane (crawler versions >= v0.9.0 only).
  EOF
  default = null
}

variable "repo_secret_arn" {
  type        = string
  description = <<EOF
    ARN of the entry in AWS Secrets Manager that stores the secret containing
    the credentials to connect to the repository. Either this OR the
    `repo_username` and `repo_password` variables are REQUIRED. If empty, the
    `repo_username` and `repo_password` variables MUST both be provided, and a
    new secret will be created in AWS Secrets Manager.
  EOF
  default     = ""
}

variable "repo_username" {
  type        = string
  description = <<EOF
    The username to connect to the repository. This is REQUIRED if the
    `repo_secret_arn` variable is empty and there is no database user
    mapped to the repository on the Control Plane.
  EOF
  default     = ""
}

variable "repo_password" {
  type        = string
  description = <<EOF
    The password to connect to the repository. This is REQUIRED if the
    `repo_secret_arn` variable is empty.
  EOF
  default     = ""
  sensitive   = true
}

variable "repo_database" {
  type        = string
  description = <<EOF
    The database on the repository that the repo crawler will connect to. If
    omitted, the crawler will attempt to connect to and crawl all databases
    accessible on the server (crawler versions >= v0.9.0 only).
  EOF
  default     = ""
}

variable "repo_sample_size" {
  type        = number
  description = "Number of rows to sample from each table."
  default     = 5
}

variable "repo_query_timeout" {
  type        = string
  description = <<EOF
    The maximum time any query can take before being canceled, as a duration
    string, e.g. 10s or 5m. If zero or negative, there is no timeout.
  EOF
  default     = "0s"
}

variable "repo_max_open_conns" {
  type        = number
  description = "Maximum number of open connections to the database."
  default     = 10
}

variable "repo_max_parallel_dbs" {
  type        = number
  description = <<EOF
    Advanced option to configure the maximum number of databases to crawl in
    parallel. This only applies if sampling all databases on the server, i.e.
    if the database is omitted. If zero, there is no limit.
  EOF
  default     = 0
}

variable "repo_max_concurrency" {
  type        = number
  description = <<EOF
    Advanced option to configure the maximum number of concurrent query
    goroutines. If zero, there is no limit. Applies on a per-database level.
    Each database crawled in parallel will have its own set of concurrent
    queries, bounded by this limit. If zero, there is no limit.
  EOF
  default     = 0
}

variable "repo_include_paths" {
  type        = string
  description = <<EOF
    A comma-separated list of glob patterns, in the format
    <database>.<schema>.<table>, which represent paths to include when crawling
    the database. If empty or * (default), all paths are included.
  EOF
  default     = "*"
}

variable "repo_exclude_paths" {
  type        = string
  description = <<EOF
    A comma-separated list of glob patterns, in the format
    <database>.<schema>.<table>, which represent paths to exclude when crawling
    the database. If empty (default), no paths are excluded.
  EOF
  default     = ""
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
  description = <<EOF
    Optional database connection string options in `key=value` format:
    `opt1=val1`, `opt2=val2`, etc. Currently only works for PostgreSQL-like
    repos (i.e. Redshift, Denodo, or PostgreSQL), where this list gets
    serialized into a comma separated string.
  EOF
  default     = []
}

# Lambda and networking configuration
variable "vpc_id" {
  type        = string
  description = "The VPC the lambda will be attached to."
}

variable "subnet_ids" {
  type        = list(string)
  description = <<EOF
    The subnets that the Repo Crawler Lambda function will be deployed to. All
    subnets must be able to reach both the Cyral Control Plane and the database
    being crawled. These subnets must also support communication with
    CloudWatch and Secrets Manager, therefore outbound internet access is
    likely required.
  EOF
}

variable "timeout" {
  type        = number
  description = "The timeout of the Repo Crawler Lambda function, in seconds."
  default     = 300
}

variable "crawler_version" {
  type        = string
  description = "The version of the Cyral Repo Crawler to use, e.g. v1.2.3."
}

variable "crawler_name" {
  type        = string
  description = <<EOF
    The name of the Repo Crawler Lambda function. If omitted, it will default
    to `cyral-repo-crawler-<16 character random alphanumeric string>`.
  EOF
  default     = ""
}

variable "dynamodb_cache_table_name_suffix" {
  type        = string
  description = <<EOF
    The suffix for the DynamoDB table name used for the classification cache.
    The full table will be prefixed with the Lambda function name
    (default: cyralRepoCrawlerCache).
  EOF
  default     = "cyralRepoCrawlerCache"
}

variable "schedule_expression" {
  type        = string
  description = <<EOF
    Schedule expression to invoke the repo crawler. The default value
    represents a run schedule of every six hours.
  EOF
  default     = "cron(0 0/6 * * ? *)"
  validation {
    condition     = can(regex("^cron\\(([^ ]+ ){5}[^ ]+\\)|rate\\([^ ]+ [^ ]+\\)$", var.schedule_expression))
    error_message = "Expression must be either cron(...) or rate(...). See https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-create-rule-schedule.html."
  }
}

variable "enable_data_classification" {
  type        = bool
  description = <<EOF
    Configures the Crawler to run in data classification mode, i.e., sample and
    classify data according to a set of existing labels.
  EOF
  default     = true
}

variable "enable_account_discovery" {
  type        = bool
  description = <<EOF
    Configures the Crawler to run in account discovery mode, i.e., query and
    discover all existing user accounts in the database.
  EOF
  default     = true
}
