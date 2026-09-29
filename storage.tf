# storage.tf
#
# A private S3 bucket the whole fleet can read/write via the shared IAM
# role in iam.tf. Same random-suffix pattern as the base project's data
# bucket - S3 bucket names are globally unique across every AWS account.

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-data-${random_id.bucket_suffix.hex}"

  # Lets "terraform destroy" remove the bucket even if hosts have written
  # telemetry objects into it. Fine for a portfolio/lab project; you'd
  # normally drop this on a bucket holding real production data.
  force_destroy = true

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Simulates a retention policy for a "data library": anything hosts write
# under telemetry/ (think: status reports, metrics dumps) auto-expires
# after 30 days instead of accumulating forever and quietly costing money.
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "expire-telemetry"
    status = "Enabled"

    filter {
      prefix = "telemetry/"
    }

    expiration {
      days = 30
    }
  }
}
