# main.tf (modules/host)
#
# A single EC2 instance. Deliberately small: this module's only job is
# "launch one host with these inputs" - hosts.tf decides how many of them
# to create (via for_each) and what makes each one unique.

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.iam_instance_profile
  key_name               = var.key_name

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  user_data = var.user_data

  tags = {
    Name = var.name_tag
  }
}
