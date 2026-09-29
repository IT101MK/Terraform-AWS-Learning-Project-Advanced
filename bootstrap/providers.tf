# providers.tf (bootstrap)
#
# Not called out explicitly in the original file list, but a working config
# needs a provider block somewhere - kept separate from main.tf to mirror
# the root project's versions.tf/providers.tf split.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "terraform-advanced-bootstrap"
      ManagedBy = "terraform"
    }
  }
}
