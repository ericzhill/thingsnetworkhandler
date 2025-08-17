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

# Discover the latest GitHub release (public API)
data "http" "latest_release" {
  url = "https://github.com/ericzhill/thingsnetworkhandler/releases/download/${var.deployed_version}/lambda.zip"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

# Bucket to stage the Lambda artifact
resource "aws_s3_bucket" "artifacts" {
  bucket = lower(replace("${random_pet.prefix.id}-${random_id.bucket_suffix.hex}-lambda-artifacts", "_", "-"))
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload the artifact to S3 using the downloaded body
resource "aws_s3_object" "lambda_zip" {
  bucket         = aws_s3_bucket.artifacts.id
  key            = "deployment/lambda.zip"
  content_base64 = data.http.latest_release.response_body_base64
  content_type   = "application/zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${random_pet.prefix.id}-thingsnetworkhandler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the basic execution policy that grants CloudWatch Logs permissions
resource "aws_iam_role_policy_attachment" "cw_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Explicit log group for the Lambda, named with the random pet prefix
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${random_pet.prefix.id}-thingsnetworkhandler"
  retention_in_days = 14
}

moved {
  from = aws_lambda_function.this
  to   = aws_lambda_function.lambda_handler
}

# Create the Lambda function from the S3 object
resource "aws_lambda_function" "lambda_handler" {
  function_name = "${random_pet.prefix.id}-thingsnetworkhandler"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "provided.al2"
  handler       = "bootstrap"
  architectures = ["x86_64"]

  s3_bucket = aws_s3_bucket.artifacts.id
  s3_key    = aws_s3_object.lambda_zip.key

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

# Public Lambda Function URL
resource "aws_lambda_function_url" "public" {
  function_name      = aws_lambda_function.lambda_handler.function_name
  authorization_type = "NONE"
}
