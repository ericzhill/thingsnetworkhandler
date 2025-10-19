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
