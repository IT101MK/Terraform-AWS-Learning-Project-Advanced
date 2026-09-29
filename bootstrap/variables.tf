# variables.tf (bootstrap)
#
# Deliberately minimal. This config only ever needs to run once (or rarely,
# if you ever need to recreate the backend), so there's no need for the
# richer variable set the root project has.

variable "aws_region" {
  description = "AWS region to create the state bucket and lock table in. Should match the aws_region you plan to use for the root project."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for the state bucket and lock table. Should match the root project's project_name for easy identification, but the two are otherwise unrelated."
  type        = string
  default     = "tf-advanced"
}
