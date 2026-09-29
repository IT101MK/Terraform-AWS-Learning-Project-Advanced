# main.tf (bootstrap)
#
# STAGE 0 - run this FIRST, and only once.
#
# Chicken-and-egg problem: the root project stores its state in an S3
# bucket, but that bucket has to be created by SOMETHING before Terraform
# can point its backend at it. This tiny config is that "something".
#
# Unlike the root project, this config keeps its state LOCALLY
# (terraform.tfstate right here in bootstrap/, gitignored) and is NOT
# destroyed at the end of a session the way the rest of the project is.
# It has to keep existing as long as the root project's remote state lives
# inside the bucket it creates - destroying this config would delete the
# bucket (and every other project's state, if you reuse it) out from under
# you. Treat bootstrap/ as a permanent, rarely-touched foundation, separate
# from the tear-down/rebuild cycle you use for everything else.

# random_id gives the bucket name a globally-unique suffix, same pattern as
# the data bucket in the root project's storage.tf.
resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-tfstate-${random_id.state_bucket_suffix.hex}"

  # No force_destroy here on purpose. This bucket holds state files, not
  # disposable lab data - accidentally running "terraform destroy" in this
  # directory should NOT be a one-command way to wipe your state history.
  tags = {
    Name = "${var.project_name}-tfstate"
  }
}

# Versioning means every write to the state file keeps its prior version.
# If a bad apply corrupts state, you can restore the previous object
# version from the S3 console instead of losing history entirely.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Default server-side encryption (SSE-S3, AES256). State files can contain
# sensitive values (e.g. resource attributes), so encryption at rest is a
# baseline expectation, not an optional extra.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access, same belt-and-suspenders pattern as the root
# project's data bucket - state files should never be reachable publicly.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Classic locking pattern, included for familiarity; the main config
# actually uses Terraform's native S3 locking instead (use_lockfile = true
# in backend.hcl, requires Terraform >= 1.10). DynamoDB locking was the
# standard approach for years and you'll see it in most existing Terraform
# codebases, so it's worth having one example of it here even though this
# project doesn't depend on it.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST" # No capacity planning needed for a table this small and low-traffic.
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-tf-locks"
  }
}
