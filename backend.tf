# backend.tf
#
# An intentionally EMPTY backend block. This is "partial configuration" -
# Terraform knows it should use the S3 backend, but the actual bucket/
# region/key values are supplied separately at init time with:
#
#   terraform init -backend-config=backend.hcl
#
# Why not just fill the values in here? Because bucket names are unique
# per-person (they include a random suffix from bootstrap/) and shouldn't
# be hardcoded into version-controlled .tf files. backend.hcl.example shows
# the shape; you copy it to backend.hcl (gitignored) and fill in your own
# bucket name from the bootstrap output.
terraform {
  backend "s3" {}
}
