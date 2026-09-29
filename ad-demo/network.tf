# network.tf
#
# A minimal, dedicated VPC that exists purely to satisfy AWS Managed
# Microsoft AD's prerequisites: a VPC with at least two subnets, each in a
# DIFFERENT Availability Zone. This VPC shares nothing with the sibling
# root project's 10.0.0.0/16 VPC - no peering, no shared route tables, no
# data source lookups into it. 10.99.0.0/16 was picked deliberately far
# from 10.0.0.0/16 so the two are never visually confused in the console.
#
# No NAT Gateway, same cost-avoidance rule as the root project. An Internet
# Gateway is included (and the subnets are "public") only so that, if you
# later launch a test EC2 instance here to prove a domain join, it can
# reach the internet without extra plumbing. The directory's own domain
# controllers are managed by AWS and don't need a public IP.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block = "10.99.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
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

# AWS Managed Microsoft AD requires exactly this: two subnets, two
# different AZs, same network type. We pull the first two available AZs in
# the region rather than hardcoding names like "us-east-1a" - AZ names are
# mapped differently to physical locations per AWS account.
resource "aws_subnet" "a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.99.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-a"
  }
}

resource "aws_subnet" "b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.99.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-b"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.b.id
  route_table_id = aws_route_table.public.id
}

# No security group resource here on purpose - aws_directory_service_directory
# creates and manages its own security group automatically (exposed as the
# security_group_id output attribute in outputs.tf).
