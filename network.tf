# network.tf
#
# Same shape as the base project: one VPC, one public subnet, an Internet
# Gateway, and the routing that makes the subnet public. No NAT Gateway -
# that's a deliberate cost-avoidance choice (NAT Gateways bill by the hour
# AND per GB processed, easily the single most expensive line item in a
# learning AWS bill). Every host here lives on the public subnet and reaches
# the internet directly through the IGW.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  # Every host gets a public IP automatically. Remember: each one of these
  # is a small hourly charge (see the host_count variable description).
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# One security group shared by every host in the fleet (mirrors iam.tf's
# "one role for the whole fleet" simplification, for the same reason: all
# hosts do identical work, so identical firewall rules make sense).
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP from anywhere; SSH only if ssh_allowed_cidr is set"
  vpc_id      = aws_vpc.main.id

  # LAB ONLY: plain HTTP (no TLS) open to the whole internet, serving a demo
  # status page. Fine for a short-lived, destroy-every-session lab; not a
  # pattern to copy into anything real. A production service would sit
  # behind a load balancer with HTTPS, restrict or drop port 80, and keep
  # the hosts in a private subnet (see "What to learn next" in the README).
  ingress {
    description = "HTTP from anywhere (lab demo only)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # A dynamic block only produces an "ingress" rule when its for_each has
  # elements. We give it a one-item list when ssh_allowed_cidr is set, and
  # an empty list (so: no SSH rule at all) when it's null. This is how you
  # conditionally include a whole block in Terraform - there's no plain
  # "if" you can wrap around a static block.
  dynamic "ingress" {
    for_each = var.ssh_allowed_cidr != null ? [var.ssh_allowed_cidr] : []

    content {
      description = "SSH from my IP (optional fallback - SSM is primary)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
