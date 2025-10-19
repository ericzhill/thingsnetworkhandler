# Discover the latest GitHub release (public API)
data "http" "latest_release" {
  url = "https://github.com/ericzhill/thingsnetworkhandler/releases/download/${var.deployed_version}/lambda.zip"

  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

# Upload the artifact to S3 using the downloaded body
resource "aws_s3_object" "lambda_zip" {
  bucket             = aws_s3_bucket.artifacts.id
  key                = "deployment/lambda.zip"
  content_base64     = data.http.latest_release.response_body_base64
  content_type       = "application/zip"
  checksum_algorithm = "SHA256"
}
