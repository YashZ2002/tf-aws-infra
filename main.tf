provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# VPC creation
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "my-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.availability_zones, count.index)
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 3, count.index + 3)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my-internet-gateway"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "my-public-route-table"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public_associations" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table (example without NAT)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my-private-route-table"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_associations" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

# New part: Application Security Group
resource "aws_security_group" "app_security_group" {
  vpc_id = aws_vpc.my_vpc.id
  name   = "app-security-group"

  # Ingress rules: Allow TCP traffic on 22, 80, 443, and application port
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.application_port
    to_port     = var.application_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-security-group"
  }
}

# New part: EC2 Instance with Custom AMI
resource "aws_instance" "app_instance" {
  ami           = var.custom_ami_id # Add the AMI ID generated by your custom Packer image
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.app_security_group.id]

  # Add key_name to associate the key pair for SSH access


  root_block_device {
    volume_type           = "gp2"
    volume_size           = 25
    delete_on_termination = true
  }

  subnet_id = aws_subnet.public_subnets[0].id
  # Disable termination protection
  disable_api_termination = false
  tags = {
    Name = "app-instance"
  }
}

