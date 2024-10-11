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
    security_groups = [aws_security_group.alb_sg.id]
    
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
  ami                         = "ami-0fff1b9a61dec8a5f"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  key_name                    = data.aws_key_pair.key.key_name
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  user_data                   = file("comandsEC1.sh")

  associate_public_ip_address = true
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
  user_data                   = file("comandsEC2.sh")

    tags = {
      Name = "EC2_Public_2"
    }
}

# Crear un Target Group para asociar las instancias EC2
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.cloud2_vpc.id
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "app-target-group"
  }
}

# Crear un Security Group para el ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.cloud2_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfico HTTP desde cualquier lugar
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb_security_group"
  }
}

# Crear el Load Balancer (Application Load Balancer)
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]  # SG para el ALB
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]  # Subnets donde desplegar el ALB

  tags = {
    Name = "app-load-balancer"
  }
}

# Crear un Listener para que el ALB redirija el tráfico al Target Group
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  tags = {
    Name = "app-listener"
  }
}


# Añadir instancias EC2 al Target Group
resource "aws_lb_target_group_attachment" "ec2_attachment_1" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.ec2_public_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_attachment_2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.ec2_public_2.id
  port             = 80
}

# Security Group para el Load Balancer
resource "aws_security_group" "app_lb_sg" {
  vpc_id = aws_vpc.cloud2_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfico entrante en el puerto 80 desde cualquier IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AppLoadBalancerSG"
  }
}


# Security Group para permitir acceso a la base de datos
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.cloud2_vpc.id

  ingress {
    from_port   = 3306   # Puerto para MySQL, ajusta según el motor que uses
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfico desde cualquier IP (ajusta si es necesario)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Permitir todo el tráfico saliente
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}

# Crear un grupo de subnets para RDS (asegúrate de que sean subnets privadas)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "RDSSubnetGroup"
  }
}

# Crear una instancia RDS MySQL
resource "aws_db_instance" "default" {
  allocated_storage    = 20                   
  storage_type         = "gp2"                
  engine               = "mysql"              
  engine_version       = "8.0.35"            
  instance_class       = "db.t3.micro"        
  db_name                 = "mydb"            
  username             = "admin"             
  password             = "password123"       
  parameter_group_name = "default.mysql8.0"   
  skip_final_snapshot  = true     
  publicly_accessible  = false


  vpc_security_group_ids = [aws_security_group.rds_sg.id]  # Asociar el SG que permite tráfico a la BD
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name

  tags = {
    Name = "MyRDSInstance"
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
output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}

output "rds_db_name" {
  value = aws_db_instance.default.db_name
}

output "rds_username" {
  value = aws_db_instance.default.username
}