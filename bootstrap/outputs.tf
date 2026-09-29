# outputs.tf (bootstrap)
#
# These values feed straight into backend.hcl.example in the root project.
# After "terraform apply" here, run "terraform output state_bucket_name"
# and paste the result into backend.hcl's "bucket" line.

output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state. Copy this into backend.hcl as the 'bucket' value."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket, useful if you later write an IAM policy scoping who can read/write state."
  value       = aws_s3_bucket.state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB lock table. Not used by the root project (which uses native S3 locking), kept for reference/familiarity only."
  value       = aws_dynamodb_table.terraform_locks.name
}
