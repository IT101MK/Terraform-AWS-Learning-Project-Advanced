# variables.tf (modules/host)
#
# Everything this module needs is passed in explicitly by hosts.tf - the
# module itself has no idea about project_name, var.aws_region, or any
# other root-level variable. That's the point of a module: it's a small,
# self-contained building block that only knows what it's told.

variable "ami_id" {
  description = "AMI ID to launch the instance from."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into."
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance."
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile to attach."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair, or null for none."
  type        = string
  default     = null
}

variable "root_volume_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
}

variable "user_data" {
  description = "Rendered user_data script to run on first boot."
  type        = string
}

variable "name_tag" {
  description = "Value for this instance's Name tag."
  type        = string
}
