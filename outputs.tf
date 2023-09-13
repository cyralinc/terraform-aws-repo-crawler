output "repo_crawler_lambda_function_arn" {
  value = aws_lambda_function.this.arn
  description = "The Amazon Resource Name (ARN) of the Repo Crawler Lambda function."
}

output "repo_crawler_aws_security_group_id" {
  value = aws_security_group.this.id
  description = "The Amazon Security Group ID of the Repo Crawler Lambda function."
}
