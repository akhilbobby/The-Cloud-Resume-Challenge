output "function_name" {
  description = "Name of the Lambda function."

  value = aws_lambda_function.lambda-visitorcounter.function_name
}

output "environment_table_name" {
  description = "Name of the environment DynamoDB table"
  value       = aws_dynamodb_table.dynamo-visitorcounter.name
}

output "environment_table_arn" {
  description = "ARN of the environment DynamoDB table"
  value       = aws_dynamodb_table.dynamo-visitorcounter.arn
}

# output "lambda-url" {
#   description = "InvokeURL"

#   value = aws_apigatewayv2_stage.dev.invoke_url
# }