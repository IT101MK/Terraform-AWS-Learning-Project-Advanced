# versions.tf (bootstrap)
#
# Same idea as the root project's versions.tf: pin Terraform and provider
# versions so this config behaves the same today as it will in six months.

terraform {
  # 1.10.0+ is required by the ROOT project (native S3 state locking). We
  # pin the same floor here too, purely for consistency across the repo -
  # this bootstrap config doesn't itself need any 1.10 feature.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }

    # Used to generate a random suffix for the state bucket name, same
    # pattern as the data bucket in the root project's storage.tf.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
