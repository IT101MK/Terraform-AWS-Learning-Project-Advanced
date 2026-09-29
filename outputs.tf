# outputs.tf
#
# Printed after "terraform apply"; re-print anytime with "terraform output"
# (read-only, makes no changes).

output "host_public_ips" {
  description = "Public IP address of each host, keyed by host key (\"01\", \"02\", ...)."
  value       = { for key, host in module.host : key => host.public_ip }
}

output "bucket_name" {
  description = "Name of the private S3 bucket the fleet can read/write."
  value       = aws_s3_bucket.data.bucket
}

output "dashboard_url" {
  description = "Direct link to the CloudWatch dashboard for this fleet."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.fleet.dashboard_name}"
}

output "ssh_commands" {
  description = "Example SSH command per host - only meaningful if both ssh_allowed_cidr and key_pair_name are set. Otherwise, use SSM: aws ssm start-session --target <instance-id>."
  value = (
    var.ssh_allowed_cidr != null && var.key_pair_name != null
    ? { for key, host in module.host : key => "ssh -i ${var.key_pair_name}.pem ec2-user@${host.public_ip}" }
    : { note = "SSH not configured (ssh_allowed_cidr and/or key_pair_name unset). Use SSM instead: aws ssm start-session --target <instance-id> - see host_instance_ids output." }
  )
}

output "host_instance_ids" {
  description = "EC2 instance ID of each host, keyed by host key - handy for 'aws ssm start-session --target <id>'."
  value       = { for key, host in module.host : key => host.instance_id }
}
