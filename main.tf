terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
      }
      archive = {
        source = "hashicorp/archive"
        version = "~> 2.0"
      }
    }
}

provider "aws" {
    region = "us-east-1"
}

/* dynamoDB Table Creation */

resource "aws_dynamodb_table" "messages" {
  name          = "messages-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}


/* Package lambda */
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda/app.py"
  output_path = "lambda/app.zip"
}

/* IAM Role for Lambda */
resource "aws_iam_role" "lambda_role" {
  name = "lambda-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "lambda.amazonaws.com"
        }
    }]
  })
}

/* IAM Policy (DynamoDB + Logs) */

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = [
                "logs:*"
            ]
            Effect = "Allow"
            Resource = "*"
        },
        {
            Action = [
                "dynamodb:PutItem"
            ]
            Effect = "Allow"
            Resource = aws_dynamodb_table.messages.arn
        }
    ]
  })
}

/* Lambda Resource */
resource "aws_lambda_function" "api" {
  function_name = "serverless-api"

  filename = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler = "app.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.lambda_role.arn
}

/* API Gateway */
resource "aws_apigatewayv2_api" "api" {
  name = "serverless-api"
  protocol_type = "HTTP"
}

/* Connect API to Lambda */
resource "aws_apigatewayv2_integration" "lambda" {
  api_id = aws_apigatewayv2_api.api.id

  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.api.invoke_arn
}

/* Route Creation */
resource "aws_apigatewayv2_route" "route" {
  api_id = aws_apigatewayv2_api.api.id
  route_key = "POST /message"

  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

/* Deploy API */
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.api.id
  name = "$default"
  auto_deploy = true
}

/* Allow API Gatway to invoke Lambda */
resource "aws_lambda_permission" "api" {
  statement_id = "AllowAPIGateway"
  action ="lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal = "apigateway.amazonaws.com"
}

#terraform review
#code review