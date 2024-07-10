# Cyral Configuration
variable "control_plane_host" {
  type        = string
  description = "The host for the Cyral Control Plane API, e.g. tenant.app.cyral.com."
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

variable "repo_secret_arns" {
  type = list(string)
  description = "Secret ARN's to provide get access for the lambda."
  
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

# Lambda and networking configuration
variable "vpc_id" {
  type        = string
  default = ""
  description = "The VPC the lambda will be attached to."
}

variable "subnet_ids" {
  type        = list(string)
  default = [""]
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
    to `cyral-repo-crawler-16 character random alphanumeric string`.
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
