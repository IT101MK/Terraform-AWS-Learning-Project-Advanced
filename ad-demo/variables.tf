# variables.tf
#
# Inputs to this config. See terraform.tfvars.example for how to supply
# your own values - everything has a sane default except directory_password,
# which you must supply yourself (never commit a real password).

variable "aws_region" {
  description = "AWS region to create all resources in. Same default as the sibling root project, purely for consistency - this config's VPC and directory are otherwise completely separate."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names (e.g. <project_name>-vpc). Deliberately distinct from the root project's \"tf-advanced\" so the two are never confused in the console or in Cost Explorer."
  type        = string
  default     = "tf-advanced-ad-demo"
}

variable "directory_name" {
  # AWS Managed Microsoft AD requires a fully qualified domain name, e.g.
  # "corp.example.com" - it validates the STRING SHAPE (valid DNS-style
  # labels separated by dots), not that you actually own or can resolve the
  # domain. ".internal" was formally reserved by ICANN in 2024 specifically
  # for private, non-internet-routable naming like this, so it's a safer
  # default than borrowing a real public suffix such as ".com" you don't
  # own. Avoid a domain name that matches (or will ever match) a Route 53
  # private hosted zone you use elsewhere - AWS's own docs call out that
  # this causes DNS resolution conflicts.
  description = "Fully qualified domain name for the directory, e.g. corp.tfadvanced.internal. Must look like a real FQDN (AWS validates the format, not ownership/resolvability)."
  type        = string
  default     = "corp.tfadvanced.internal"
}

variable "directory_short_name" {
  description = "NetBIOS-style short name for the directory, e.g. CORP. Conventionally short (<= 15 chars) and uppercase."
  type        = string
  default     = "CORP"
}

variable "directory_password" {
  # AWS Managed Microsoft AD's admin password requirements (per the current
  # Directory Service admin guide):
  #   - 8 to 64 characters, case-sensitive
  #   - must NOT contain the word "admin"
  #   - must contain characters from at least 3 of these 4 categories:
  #       lowercase letters, uppercase letters, digits, non-alphanumeric
  # The validation blocks below check the length, the "admin" exclusion,
  # and the 3-of-4 character mix, but Terraform can't verify AWS will
  # accept it beyond that - double-check against the console error, if any,
  # on first apply.
  description = "Password for the directory's built-in Admin account. NO DEFAULT - you must supply this yourself (in a gitignored terraform.tfvars, or via TF_VAR_directory_password). Never commit a real value."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.directory_password) >= 8 && length(var.directory_password) <= 64
    error_message = "directory_password must be between 8 and 64 characters."
  }

  validation {
    condition     = !can(regex("(?i)admin", var.directory_password))
    error_message = "directory_password must not contain the word \"admin\" (AWS rejects it)."
  }

  validation {
    condition = (
      (length(regexall("[a-z]", var.directory_password)) > 0 ? 1 : 0) +
      (length(regexall("[A-Z]", var.directory_password)) > 0 ? 1 : 0) +
      (length(regexall("[0-9]", var.directory_password)) > 0 ? 1 : 0) +
      (length(regexall("[^a-zA-Z0-9]", var.directory_password)) > 0 ? 1 : 0)
    ) >= 3
    error_message = "directory_password must contain characters from at least 3 of: lowercase, uppercase, digits, non-alphanumeric."
  }
}

variable "directory_edition" {
  description = "AWS Managed Microsoft AD edition. \"Standard\" is the cheapest tier and all this demo needs; \"Enterprise\" costs significantly more per hour."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Enterprise"], var.directory_edition)
    error_message = "directory_edition must be \"Standard\" or \"Enterprise\"."
  }
}
