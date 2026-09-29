# outputs.tf (modules/host)
#
# What the root config gets back for each host it creates. hosts.tf
# collects these across all module instances to build the outputs.tf
# maps (host_public_ips, etc).

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the instance."
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}
