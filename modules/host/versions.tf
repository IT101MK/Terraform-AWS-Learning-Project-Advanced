# versions.tf (modules/host)
#
# Modules should pin their own required_providers too, independent of the
# root config. Terraform merges these constraints with the root's, and
# having them here means the module is self-documenting if it's ever
# reused elsewhere or published separately.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}
