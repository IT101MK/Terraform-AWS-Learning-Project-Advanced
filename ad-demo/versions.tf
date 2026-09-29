# versions.tf
#
# Same pin as the rest of the repo (bootstrap/, the root project): fix
# Terraform and provider versions so this behaves the same today as it will
# in six months. This config is otherwise fully independent of the sibling
# root project - it just happens to share the same version floor.

terraform {
  # >= 1.10.0 for native S3 state locking (use_lockfile = true in
  # backend.hcl.example), same reasoning as the root project's versions.tf.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}
