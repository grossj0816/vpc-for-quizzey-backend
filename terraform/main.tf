terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tc-terraform-state-storage-s3"
    key            = "app-quizzey-networking"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}


provider "aws" {
  region = "us-east-1"
}

//VPC
resource "aws_vpc" "quizzey_app_vpc" {
  cidr_block = "10.0.0.0/16"
  # enable_dns_hostnames = true
  # enable_dns_support = true
  tags = {
    Name = "Quizzey VPC"
  }
}


# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.quizzey_app_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true


  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}


# Lambda Subnets
resource "aws_subnet" "lambda_subnet" {
  count             = length(var.lambda_subnet_cidrs) //setting how many lambda subnets we will create by count of cidr ranges given
  vpc_id            = aws_vpc.quizzey_app_vpc.id
  cidr_block        = element(var.lambda_subnet_cidrs, count.index) //retrieving specific cidr range from lambda_subnet_cidrs list
  availability_zone = element(var.azs, count.index)


  tags = {
    Name = "Lambda Subnet ${count.index + 1}"
  }
}


# Database Subnets
resource "aws_subnet" "database_subnet" {
  count             = length(var.database_subnet_cidrs) //setting how many lambda subnets we will create by count of cidr ranges given
  vpc_id            = aws_vpc.quizzey_app_vpc.id
  cidr_block        = element(var.database_subnet_cidrs, count.index) //retrieving specific cidr range from lambda_subnet_cidrs list
  availability_zone = element(var.azs, count.index)


  tags = {
    Name = "Database Subnet ${count.index + 1}"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.quizzey_app_vpc.id

  tags = {
    Name = "Quizzey VPC Internet Gateway"
  }
}

# Elastic IP
resource "aws_eip" "nat_eip" {
  domain        = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0) //we are returning the first  public subnet as the pool of ips that can be assiged to a private ip to request out to the internet.
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "Quizzey VPC NAT Gateway"
  }
}


# Route Tables -----------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.quizzey_app_vpc.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.quizzey_app_vpc.id
}


# Routes -----------------------------------------------------------------
resource "aws_route" "internet_gw_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route" "nat_gw_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}


# Route Table Associations -----------------------------------------------
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "lambda_assoc" {
  count          = length(var.lambda_subnet_cidrs)
  subnet_id      = element(aws_subnet.lambda_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}


resource "aws_route_table_association" "database_assoc" {
  count          = length(var.database_subnet_cidrs)
  subnet_id      = element(aws_subnet.database_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# Security Groups -------------------------------------
resource "aws_security_group" "lambda_sg" {
  name        = "quizzey_lambda_sg"
  description = "Security group for lambdas made for use by Quizzey"
  vpc_id      = aws_vpc.quizzey_app_vpc.id

  //allow outbound traffic to database sg
  dynamic "egress" {
    iterator = cidr
    for_each = var.database_subnet_cidrs
    content {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [cidr.value]
    }
  }

  tags = {
    Name = "Quizzey Lambda SG"
  }
}


resource "aws_security_group" "db_sg" {
  name        = "quizzey_db_sg"
  description = "Security group for quizzey database"
  vpc_id      = aws_vpc.quizzey_app_vpc.id


  //allow incoming traffic from lambda subnets
  dynamic "ingress" {
    iterator = cidr
    for_each = var.lambda_subnet_cidrs
    content {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [cidr.value]
    }
  }

  //allow outgoing traffic from lambda subnets
  dynamic "egress" {
    iterator = cidr
    for_each = var.lambda_subnet_cidrs
    content {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = [cidr.value]
    }
  }

  tags = {
    Name = "Quizzey DB SG"
  }
}




# # # DB Subnet Group --------------------------------
resource "aws_db_subnet_group" "quizzey_db_subnet_group" {
  name        = "quizzey_db_subnet_group"
  description = "DB subnet group for Quizzey App"

  subnet_ids = [for subnet in aws_subnet.database_subnet : subnet.id]
}