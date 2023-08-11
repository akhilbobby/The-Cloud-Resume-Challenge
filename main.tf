provider "aws" {
  region = var.aws_region
  shared_config_files      = ["/Users/akhil/.aws/config"]
  shared_credentials_files = ["/Users/akhil/.aws/credentials"]
  profile                  = "CRCadmin"
}

################################## LAMBDA #############################


#archive file
data "archive_file" "zip-python" {
  type        = "zip"
  source_file = "lambda-counter.py"
  output_path = "lambda-counter.zip"
}

#upload archive to s3 
resource "aws_s3_object" "lambda-in-s3" {
  bucket = "akhilresume.com"
  key    = "lambda-counter.zip"
  source = data.archive_file.zip-python.output_path
  etag = filemd5(data.archive_file.zip-python.output_path)
}



resource "aws_lambda_function" "lambda-visitorcounter" {
  function_name = "visitor-counter"

  s3_bucket = "akhilresume.com"
  s3_key    = aws_s3_object.lambda-in-s3.key

  runtime = "python3.9"
  handler = "lambda-counter.lambda_handler"

  #source_code_hash attribute will change whenever you update the code contained in the archive, which lets Lambda know that there is a new version of your code available.
  source_code_hash = data.archive_file.zip-python.output_base64sha256

  # a role which grants the function permission to access AWS services and resources in your account.
  role = aws_iam_role.lambda_exec.arn
}

#defines a log group to store log messages from your Lambda function for 30 days. By convention, Lambda stores logs in a group with the name /aws/lambda/<Function Name>.
resource "aws_cloudwatch_log_group" "lambda-visitorcounter" {
  name = "/aws/lambda/${aws_lambda_function.lambda-visitorcounter.function_name}"

  retention_in_days = 30
}

#defines an IAM role that allows Lambda to access resources in your AWS account.
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

#attaches a policy to the IAM role. The AWSLambdaBasicExecutionRole is an AWS managed policy that allows your Lambda function to write to CloudWatch logs.
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_dynamoroles" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}



  ###################### DYNAMO D B #####################

resource "aws_dynamodb_table" "dynamo-visitorcounter" {
  name         = "db-visit-count"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "user"

  attribute {
    name = "user"
    type = "S"
  }

}


####################### HTTP API GATEWAY #####################

resource "aws_apigatewayv2_api""api-lambda-counter"{
  name = "api-lambda-counter"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "dev"{
  api_id = aws_apigatewayv2_api.api-lambda-counter.id

  name = "dev"
  auto_deploy = true
}

#integration
resource "aws_apigatewayv2_integration" "api-lambda" {
  api_id = aws_apigatewayv2_api.api-lambda-counter.id
  integration_uri = aws_lambda_function.lambda-visitorcounter.invoke_arn
  payload_format_version = "2.0"
  integration_type = "AWS_PROXY"  
  integration_method = "POST"
}

#route
resource "aws_apigatewayv2_route" "api-visitor-counter" {
  api_id = aws_apigatewayv2_api.api-lambda-counter.id

  route_key = "GET /items/{user}"
  target = "integrations/${aws_apigatewayv2_integration.api-lambda.id}" 
}

#permissions
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-visitorcounter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api-lambda-counter.execution_arn}/*/*/*"
}

