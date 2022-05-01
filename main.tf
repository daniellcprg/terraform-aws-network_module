terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.12.1"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.vpc_public_subnets)
  cidr_block              = element(var.vpc_public_subnets, count.index)
  availability_zone       = element(var.vpc_azs, count.index)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    "Terraform" = "true"
    "Name"      = format("public-%d", count.index)
    "Tier"      = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.vpc_private_subnets)
  cidr_block        = element(var.vpc_private_subnets, count.index)
  availability_zone = element(var.vpc_azs, count.index)
  vpc_id            = aws_vpc.main.id

  tags = {
    "Terraform" = "true"
    "Name"      = format("private-%d", count.index)
    "Tier"      = "private"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Terraform" = "true"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Terraform" = "true"
    "Name" = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Terraform" = "true"
    "Name" = "public"
  }
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id = element(aws_subnet.private, count.index).id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id = element(aws_subnet.public, count.index).id
  route_table_id = aws_route_table.public.id
}

