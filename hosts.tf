# hosts.tf
#
# Stage 1: launches a small FLEET of identical hosts using the host module,
# instead of the single aws_instance the base project used. This is the
# "multi-host + module" step - the underlying instance resource lives in
# modules/host/main.tf; this file just decides how many to make and what's
# unique about each one.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  # Zero-padded host keys: host_count = 3 -> ["01", "02", "03"]. Padding
  # keeps hosts sorting and displaying in a sane order once host_count
  # reaches double digits, and gives every host a short, stable, human
  # -readable identifier used in its Name tag, its user_data status page,
  # and every map key in outputs.tf.
  host_keys = [for i in range(var.host_count) : format("%02d", i + 1)]
}

# One module instance per host key. for_each (over a set, hence toset())
# rather than count keeps each host's state address tied to its key
# ("module.host[\"01\"]") instead of a numeric index - so removing host
# "02" from the middle of the fleet doesn't cause Terraform to shuffle and
# recreate every host after it, the way count would.
module "host" {
  for_each = toset(local.host_keys)
  source   = "./modules/host"

  ami_id               = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  subnet_id            = aws_subnet.public.id
  security_group_ids   = [aws_security_group.web.id]
  iam_instance_profile = aws_iam_instance_profile.fleet.name
  key_name             = var.key_pair_name
  root_volume_gb       = var.root_volume_gb
  name_tag             = "${var.project_name}-host-${each.key}"

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    host_key = each.key
  })
}
