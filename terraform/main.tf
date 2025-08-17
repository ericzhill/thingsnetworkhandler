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
  url = "https://api.github.com/repos/${var.github_owner}/${var.github_repo}/releases/latest"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

locals {
  release = jsondecode(data.http.latest_release.response_body)
  # Find the lambda.zip asset from the latest release
  asset_urls       = [for a in local.release.assets : a.browser_download_url if a.name == "lambda.zip"]
  lambda_asset_url = length(local.asset_urls) > 0 ? local.asset_urls[0] : ""

  function_name = "${random_pet.prefix.id}-thingsnetworkhandler"
  role_name     = "${random_pet.prefix.id}-thingsnetworkhandler-role"
  policy_name   = "${random_pet.prefix.id}-thingsnetworkhandler-policy"
  bucket_name   = lower(replace("${random_pet.prefix.id}-${random_id.bucket_suffix.hex}-lambda-artifacts", "_", "-"))
}

# Fail early if the asset isn't found
locals {
  _assert_has_asset = length(local.lambda_asset_url) > 0 ? true : tobool("Asset 'lambda.zip' not found on the latest release")
}

# Download the lambda.zip asset (public download URL)
# Note: Release assets on public repos are accessible without auth via browser_download_url
# We request octet-stream to get the raw file instead of JSON
# This data source keeps the content in memory for use below.
data "http" "lambda_zip" {
  url = local.lambda_asset_url

  request_headers = {
    Accept = "application/octet-stream"
  }
}

# Bucket to stage the Lambda artifact
resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name
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
  key            = "${local.function_name}/lambda.zip"
  content_base64 = base64encode(data.http.lambda_zip.response_body)
  content_type   = "application/zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = local.role_name
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
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
}

# Create the Lambda function from the S3 object
resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "provided.al2"
  handler       = "bootstrap"
  architectures = ["x86_64"]

  s3_bucket = aws_s3_bucket.artifacts.id
  s3_key    = aws_s3_object.lambda_zip.key

  # Provide source code hash so updates are detected
  source_code_hash = base64sha256(data.http.lambda_zip.response_body)

  environment {
    variables = {
      TZ = "UTC"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cw_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}
