resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${var.aws_account_id}-${var.aws_region}"

  tags = {
    Name      = "${var.project_name}-terraform-state"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.id
}
