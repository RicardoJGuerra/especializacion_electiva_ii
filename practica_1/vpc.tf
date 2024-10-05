# VPC
resource "aws_vpc" "cloud2_vpc" {
  cidr_block = "30.0.0.0/16"

  tags = {
    Name = "cloud2_vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.cloud2_vpc.id
  cidr_block        = "30.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true # Ensures instances get public IPs

  tags = {
    Name = "PublicSubnet_1"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.cloud2_vpc.id
  cidr_block        = "30.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true # Ensures instances get public IPs
  tags = {
    Name = "PublicSubnet_2"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.cloud2_vpc.id
  cidr_block        = "30.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PrivateSubnet_1"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.cloud2_vpc.id
  cidr_block        = "30.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "PrivateSubnet_2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw_cloud2" {
  vpc_id = aws_vpc.cloud2_vpc.id

  tags = {
    Name = "IGW_cloud2"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table_cloud2" {
  vpc_id = aws_vpc.cloud2_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_cloud2.id
  }

  tags = {
    Name = "PublicRouteTableCloud2"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_assoc_1_cloud2" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table_cloud2.id
}

# Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_subnet_assoc_2_cloud2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table_cloud2.id
}

# NAT Gateway (for Private Subnet Internet Access)
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  
  tags = {
    Name = "NATGateway_Cloud2"
  }
}

# Private Route Table
resource "aws_route_table" "private_route_table_cloud2" {
  vpc_id = aws_vpc.cloud2_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "PrivateRouteTableCloud2"
  }
}

# Associate Private Subnet 1 with Private Route Table
resource "aws_route_table_association" "private_subnet_assoc_1_cloud2" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table_cloud2.id
}

# Associate Private Subnet 2 with Private Route Table
resource "aws_route_table_association" "private_subnet_assoc_2_cloud2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table_cloud2.id
}

# Security Group (Allow all outgoing traffic for instances)
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.cloud2_vpc.id

  ingress{
    from_port   = 22
    to_port     = 22
    protocol    = "tcp" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
    
  }
    ingress{
    from_port   = 80
    to_port     = 80
    protocol    = "tcp" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
    
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance_security_group"
  }
}


resource "aws_instance" "ec2_public_1" {
  ami                     = "ami-0fff1b9a61dec8a5f"
  instance_type           = "t2.micro"
  subnet_id               = aws_subnet.public_subnet_1.id
  key_name                = data.aws_key_pair.key.key_name
  vpc_security_group_ids  = [aws_security_group.instance_sg.id]

    tags = {
      Name = "EC2_Public_1"
    }
}

resource "aws_instance" "ec2_public_2" {
  ami                     = "ami-0fff1b9a61dec8a5f"
  instance_type           = "t2.micro"
  subnet_id               = aws_subnet.public_subnet_2.id
  key_name                = data.aws_key_pair.key.key_name
  vpc_security_group_ids  = [aws_security_group.instance_sg.id]

    tags = {
      Name = "EC2_Public_2"
    }
}

# Outputs
output "vpc_id" {
  value = aws_vpc.cloud2_vpc.id
}

output "public_subnet_1_id" {
  value = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_subnet_2.id
}

output "private_subnet_1_id" {
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_subnet_2.id
}

output "ec2_public_ip_1"{
  value = aws_instance.ec2_public_1.public_ip
}

output "ec2_public_ip_2"{
  value = aws_instance.ec2_public_2.public_ip
}