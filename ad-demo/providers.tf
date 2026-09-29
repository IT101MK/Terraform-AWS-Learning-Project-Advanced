# providers.tf
#
# Provider configuration only. Backend config lives in backend.tf, version
# pins live in versions.tf - same three-way split the sibling project uses.

provider "aws" {
  region = var.aws_region

  # A distinct Project tag from the root project ("terraform-advanced") and
  # from bootstrap ("terraform-advanced-bootstrap"), so this directory's
  # resources are unmistakable in Cost Explorer / the console even though
  # they share an account with the rest of the repo.
  default_tags {
    tags = {
      Project   = "terraform-advanced-ad-demo"
      ManagedBy = "terraform"
    }
  }
}
