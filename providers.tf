# providers.tf
#
# Provider configuration (region + default tags). Versions live in
# versions.tf; backend configuration lives in backend.tf.

provider "aws" {
  region = var.aws_region

  # Applied automatically to every taggable resource. We rely on this for
  # Project/ManagedBy so individual resources only need to set a Name tag.
  default_tags {
    tags = {
      Project   = "terraform-advanced"
      ManagedBy = "terraform"
    }
  }
}
