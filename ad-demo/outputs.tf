# outputs.tf
#
# Everything you need for the screenshot, plus a reminder not to linger.

output "directory_id" {
  description = "The directory's ID (format d-xxxxxxxxxx). Shown in the console and useful for CLI lookups (aws ds describe-directories)."
  value       = aws_directory_service_directory.main.id
}

output "dns_ip_addresses" {
  description = "IP addresses of the two domain controllers' DNS servers, one per AZ/subnet."
  value       = aws_directory_service_directory.main.dns_ip_addresses
}

output "access_url" {
  description = "AWS-assigned access URL for the directory (format https://<alias>.awsapps.com), used for things like WorkDocs/IAM Identity Center sign-in pages. Populated automatically even without setting a custom alias."
  value       = aws_directory_service_directory.main.access_url
}

output "security_group_id" {
  description = "ID of the security group AWS created and attached to the directory's network interfaces (created automatically, not managed by this config)."
  value       = aws_directory_service_directory.main.security_group_id
}

output "console_url" {
  description = "Direct link to this directory's detail page in the AWS Directory Service console. Region is passed as a query parameter, matching AWS's own documentation link format."
  value       = "https://console.aws.amazon.com/directoryservicev2/home?region=${var.aws_region}#!/directories/${aws_directory_service_directory.main.id}"
}

output "next_steps" {
  description = "What to do right now, in order."
  value       = <<-EOT
    1. Open console_url (above) and confirm Status = "Active" (allow 20-40+ minutes after apply).
    2. Take your portfolio screenshot of the directory detail page showing "Active".
    3. Run "terraform destroy" immediately - don't leave this running, it bills hourly.
  EOT
}
