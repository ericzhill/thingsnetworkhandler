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
