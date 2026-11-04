
resource "aws_s3_bucket" "media_dev" {
  bucket = "${var.project_name}-media-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-media-${var.environment}"
    Purpose = "Application media storage"
  }
}

resource "aws_s3_bucket_public_access_block" "media_dev" {
  bucket = aws_s3_bucket.media_dev.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media_dev" {
  bucket = aws_s3_bucket.media_dev.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "media_dev" {
  bucket = aws_s3_bucket.media_dev.id

  versioning_configuration {
    status = "Enabled"
  }
}
