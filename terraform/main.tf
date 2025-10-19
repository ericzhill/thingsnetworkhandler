terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random pet name prefix used for Lambda, log group, IAM role/policy, and S3 bucket
resource "random_pet" "prefix" {
  length = 2
}

# Add a small random suffix to improve S3 bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 2
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "erichill"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "thingsnetworkhandler"
}


# Create the Lambda function from the S3 object
resource "aws_lambda_function" "lambda_handler" {
  function_name = "${random_pet.prefix.id}-thingsnetworkhandler"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "provided.al2"
  handler       = "bootstrap"
  architectures = ["x86_64"]
  publish       = true

  s3_bucket        = aws_s3_bucket.artifacts.id
  s3_key           = aws_s3_object.lambda_zip.key
  source_code_hash = aws_s3_object.lambda_zip.checksum_sha256

  environment {
    variables = {
      TZ               = "UTC"
      DOWNLINK_API_KEY = var.downlink_api_key
      DEPLOYED_VERSION = var.deployed_version
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cw_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

resource "aws_lambda_alias" "lambda_handler" {
  function_name    = aws_lambda_function.lambda_handler.function_name
  function_version = aws_lambda_function.lambda_handler.version
  name             = "latest"
}

# Public Lambda Function URL
resource "aws_lambda_function_url" "public" {
  function_name      = aws_lambda_function.lambda_handler.function_name
  authorization_type = "NONE"
  qualifier          = aws_lambda_alias.lambda_handler.name
}

resource "aws_lambda_permission" "allow_public_access" {
  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.lambda_handler.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
  qualifier              = aws_lambda_alias.lambda_handler.name
}

resource "aws_lambda_permission" "allow_invoke_access" {
  statement_id  = "FunctionURLAllowInvokeAction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_handler.function_name
  principal     = "*"
  qualifier     = aws_lambda_alias.lambda_handler.name
}

output "lambda_shasum" {
  value = aws_s3_object.lambda_zip.checksum_sha256
}
