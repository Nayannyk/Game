terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ECR Repository
resource "aws_ecr_repository" "game_repo" {
  name = var.ecr_repository
}

# ECS Cluster
resource "aws_ecs_cluster" "game_cluster" {
  name = "game-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "game_task" {
  family                   = "game-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  container_definitions = jsonencode([{
    name      = "game-container"
    image     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:${var.ecr_image_tag}"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

# ECS Service
resource "aws_ecs_service" "game_service" {
  name            = "game-service"
  cluster         = aws_ecs_cluster.game_cluster.id
  task_definition = aws_ecs_task_definition.game_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.private.*.id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.game_target.arn
    container_name   = "game-container"
    container_port   = 80
  }
  
  depends_on = [aws_lb_listener.game_listener]
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "game-vpc"
  }
}

# Subnets
resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(["${var.aws_region}a", "${var.aws_region}b"], count.index)
  
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  cidr_block        = element(["10.0.101.0/24", "10.0.102.0/24"], count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(["${var.aws_region}a", "${var.aws_region}b"], count.index)
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "game-igw"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (optional for private subnets)
resource "aws_eip" "nat" {
  count = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  
  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id, count.index)
  }
  
  tags = {
    Name = "private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

# Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Load Balancer
resource "aws_lb" "game_alb" {
  name               = "game-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public.*.id
  
  tags = {
    Name = "game-alb"
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target Group
resource "aws_lb_target_group" "game_target" {
  name        = "game-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  
  health_check {
    path                = "/game.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener
resource "aws_lb_listener" "game_listener" {
  load_balancer_arn = aws_lb.game_alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game_target.arn
  }
}

# Output
output "load_balancer_dns" {
  value = aws_lb.game_alb.dns_name
  description = "The DNS name of the load balancer"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.game_repo.repository_url
}
