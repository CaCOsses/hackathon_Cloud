provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
}


resource "aws_dynamodb_table" "task_table" {
  name           = "TaskTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"
  attribute {
    name = "task_id"
    type = "S"
  }
}

resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "taskstorage"
}

# Empaquetar los archivos Python y subirlos al Bucket de S3
data "archive_file" "lambda_code_archive" {
  type        = "zip"
  output_path = "../lambda_code.zip"
  source_dir  = "../lambda"
}

resource "aws_s3_bucket_object" "lambda_code_object" {
  bucket       = aws_s3_bucket.lambda_code_bucket.bucket
  key          = "../lambda_code.zip"
  source       = data.archive_file.lambda_code_archive.output_path
  content_type = "application/zip"
}

resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "API for managing tasks"
}

resource "aws_api_gateway_resource" "task_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_method" "create_task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_api_resource.id
  http_method             = aws_api_gateway_method.create_task_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/createScheduledTask/invocations"
}

resource "aws_api_gateway_resource" "list_task_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "listtask"
}

resource "aws_api_gateway_method" "list_task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.list_task_api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.list_task_api_resource.id
  http_method             = aws_api_gateway_method.list_task_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/listScheduledTask/invocations"
}

output "rest_api_id" {
  value = aws_api_gateway_rest_api.task_api.id
}

# Configurar las Lambdas para Usar los Archivos desde S3
resource "aws_lambda_function" "create_task_lambda" {
  function_name    = "createScheduledTask"
  handler          = "createScheduledTask.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.archive_file.lambda_code_archive.output_base64sha256
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key           = aws_s3_bucket_object.lambda_code_object.key
}

resource "aws_lambda_function" "list_task_lambda" {
  function_name    = "listScheduledTask"
  handler          = "listScheduledTask.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.archive_file.lambda_code_archive.output_base64sha256
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key           = aws_s3_bucket_object.lambda_code_object.key
}

resource "aws_lambda_function" "execute_task_lambda" {
  function_name    = "executeScheduledTask"
  handler          = "executeScheduledTask.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_execution_role.arn
  source_code_hash = data.archive_file.lambda_code_archive.output_base64sha256
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key           = aws_s3_bucket_object.lambda_code_object.key
}


# Recurso para la regla de EventBridge
resource "aws_cloudwatch_event_rule" "minute_event_rule" {
  name                = "ExecuteScheduledTaskEveryMinute"
  description         = "Rule to trigger ExecuteScheduledTask every minute"
  schedule_expression = "rate(1 minute)"
}

# Recurso para conectar la regla de EventBridge con la función Lambda
resource "aws_cloudwatch_event_target" "execute_task_target" {
  rule             = aws_cloudwatch_event_rule.minute_event_rule.name
  target_id        = "executeScheduledTaskTarget"
  arn              = aws_lambda_function.execute_task_lambda.arn
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

locals {
  policy_json = jsondecode(file("${path.module}/policy.json"))
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Política IAM para funciones Lambda"
  policy      = jsonencode(local.policy_json)
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}