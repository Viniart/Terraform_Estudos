# modules/webapp/main.tf
provider "aws" {
  region = "us-east-1"
}

# Trecho que permite a utilização de Terragrunt
terraform {
  backend "s3" {}
}

# Tag Padrão
locals {
  common_tags = {
    Project = "SPSkills"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "ws-vpc" })
}

# Sub-redes na Zona de Disponibilidade 'a'
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "ws-public-subnet-a" })
}
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.50.10.0/24"
  availability_zone = "us-east-1a"
  tags              = merge(local.common_tags, { Name = "ws-private-subnet-a" })
}

# Sub-redes na Zona de Disponibilidade 'b'
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.50.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "ws-public-subnet-b" })
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.50.11.0/24"
  availability_zone = "us-east-1b"
  tags              = merge(local.common_tags, { Name = "ws-private-subnet-b" })
}

# --- Conectividade com a Internet ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "ws-igw" })
}
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "ws-nat-eip" })
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id # O NAT Gateway precisa estar em uma sub-rede pública
  tags          = merge(local.common_tags, { Name = "ws-nat-gw" })
  depends_on    = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(local.common_tags, { Name = "ws-public-rt" })
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(local.common_tags, { Name = "ws-private-rt" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}


# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Permite trafego HTTP para o ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "alb-sg" })
}
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Permite trafego do ALB e para o RDS"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "web-server-sg" })
}
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Permite trafego dos servidores web"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  tags = merge(local.common_tags, { Name = "rds-sg" })
}


# ALB
resource "aws_lb" "main" {
  name               = "webapp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = local.common_tags
}

# Target Group e Listener
resource "aws_lb_target_group" "main" {
  name     = "webapp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags     = local.common_tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "webapp-"
  image_id      = "ami-052064a798f08f0d3"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data = <<-EOF
          #!/bin/bash
          sudo dnf update -y
          sudo dnf install -y nginx
          sudo systemctl start nginx
          sudo systemctl enable nginx
          EOF
  tags = local.common_tags
}

# ASG
resource "aws_autoscaling_group" "main" {
  name                = "webapp-asg"
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  desired_capacity    = var.instance_count
  max_size            = 5
  min_size            = 1
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.main.arn]
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Alternativa - Utilizando Attachment
# resource "aws_autoscaling_attachment" "asg_to_tg" {
#   autoscaling_group_name = aws_autoscaling_group.main.name
#   target_group_arn       = aws_lb_target_group.main.arn
# }


# RDS
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = local.common_tags
}

# Cria a instância do banco de dados PostgreSQL
resource "aws_db_instance" "main" {
  identifier           = "webapp-db"
  allocated_storage    = 20
  engine               = "postgres"
  instance_class       = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.main.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username             = "master"
  password             = var.db_password
  publicly_accessible  = false
  skip_final_snapshot  = true
  tags                 = local.common_tags
}