output "repo_crawler_lambda_function_arn" {
  value = aws_lambda_function.this.arn
  description = "The Amazon Resource Name (ARN) of the Repo Crawler Lambda function."
}
