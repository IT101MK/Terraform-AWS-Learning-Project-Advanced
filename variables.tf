# variables.tf
#
# Inputs to this project. See terraform.tfvars.example for how to supply
# your own values.

variable "project_name" {
  description = "Short name used as a prefix for resource names and the S3 bucket."
  type        = string
  default     = "tf-advanced"
}

variable "aws_region" {
  description = "AWS region to create all resources in."
  type        = string
  default     = "us-east-1"
}

variable "ssh_allowed_cidr" {
  # NO forced choice this time: SSM Session Manager (via the instance
  # profile in iam.tf) is the PRIMARY way to reach these hosts, so SSH is
  # an optional fallback rather than something you must configure. Leave
  # this null and you still get a shell, just through the AWS console/CLI
  # ("aws ssm start-session") instead of a raw SSH client.
  description = "CIDR block allowed to SSH (port 22) into the hosts, e.g. 203.0.113.25/32. Optional - SSM Session Manager (via the shared IAM role) is the primary access method and works even with this left null."
  type        = string
  default     = null

  validation {
    # can() short-circuits to true when the value is null, so this only
    # actually checks the CIDR shape when you've supplied one.
    condition     = var.ssh_allowed_cidr == null || can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be null or valid CIDR notation, e.g. 203.0.113.25/32."
  }

  validation {
    condition     = var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "Do not open SSH to 0.0.0.0/0 (the entire internet). Use your own IP with /32, or leave null and use SSM instead."
  }
}

variable "key_pair_name" {
  description = "Name of an EXISTING EC2 key pair for SSH access. Leave null to launch without SSH keys - SSM Session Manager still works without one."
  type        = string
  default     = null
}

variable "host_count" {
  description = "Number of EC2 hosts to launch. Mind the cost: since Feb 2024, AWS bills ~$0.005/hr for EVERY public IPv4 address, free-tier eligible or not - so each extra host adds a small but real hourly charge on top of any instance cost."
  type        = number
  default     = 2

  validation {
    condition     = var.host_count >= 1 && var.host_count <= 5
    error_message = "host_count must be between 1 and 5."
  }
}

variable "root_volume_gb" {
  description = "Root EBS volume size (GiB) for each host. AWS's free tier gives you 30 GB of EBS storage total across the WHOLE account, not per volume - so host_count * root_volume_gb must stay <= 30 to remain fully within it."
  type        = number
  default     = 8
}

variable "instance_type" {
  description = "EC2 instance type for all hosts. t3.micro is free-tier eligible on the current AWS Free Plan, but eligibility varies by account and region - the base project had to switch from t2.micro to t3.micro for exactly this reason. Double-check your own account's Free Tier page before assuming."
  type        = string
  default     = "t3.micro"
}

variable "cpu_alarm_threshold" {
  description = "CPUUtilization percentage that triggers the per-host CloudWatch alarm."
  type        = number
  default     = 80
}

variable "enable_alarm_notifications" {
  description = "If true, create an SNS topic and email subscription so alarms actually notify someone. If false (default), alarms still exist and show up in the CloudWatch console/dashboard, they just don't page anyone."
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address to subscribe to the alarm SNS topic. Only used when enable_alarm_notifications = true; you'll get a confirmation email from AWS that you must click to activate the subscription."
  type        = string
  default     = null
}
