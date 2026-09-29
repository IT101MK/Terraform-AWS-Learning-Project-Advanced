# versions.tf
#
# Same purpose as in the bootstrap config and the base Project-IaC: pin
# Terraform and provider versions for reproducibility.

terraform {
  # >= 1.10.0 specifically (not 1.5.0 like the base project) because
  # backend.hcl below turns on use_lockfile - native S3 state locking via
  # conditional writes, which shipped in Terraform 1.10. Older Terraform
  # versions don't understand that backend argument at all.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
