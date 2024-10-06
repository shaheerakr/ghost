locals {
  name = "core-infra-ghost"
  tags = {
    Blueprint = local.name
  }
}

# VPC module for networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "ghost-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

# ALB Security Group
module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "ghost-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  ingress_rules = ["http-80-tcp"]

  egress_rules = ["all-all"]
  tags         = local.tags
}

# Security Group for ECS Task
module "ecs_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ecs-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Allow traffic from ALB to ECS"

  ingress_with_source_security_group_id = [
    {
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      description              = "Allow traffic from ALB to ECS"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}

# Application Load Balancer (ALB)
module "alb_ghost" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 8.0"
  name               = "ghost-alb-ecs"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.security_group_id]
  subnets            = module.vpc.public_subnets
  vpc_id             = module.vpc.vpc_id

  tags = local.tags
}

# ALB Target Group
resource "aws_lb_target_group" "tg" {
  name        = "ecs-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = local.tags
}

# ALB Listener to route traffic
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = module.alb_ghost.lb_arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  tags = local.tags
}

# ECS Cluster for running the application
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "ghost-ecs-cluster"
  tags         = local.tags
}

# ECS Service Definition
module "ecs_service_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = "ghost-service"
  desired_count      = 2
  cluster_arn        = module.ecs.cluster_arn
  enable_autoscaling = true
  cpu                = 512
  memory             = 1024

  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.ecs_sg.security_group_id]

  # Associate the ALB with the ECS service
  load_balancer = [{
    container_name   = "ghost"
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.tg.arn
  }]

  container_definitions = {
    ghost-service = {
      cpu       = 256
      memory    = 512
      name      = "ghost"
      image     = var.container_image
      essential = true

      port_mappings = [{
        protocol      = "tcp"
        containerPort = var.container_port
      }]
      environment = [
        { name = "url", value = "http://${module.alb_ghost.lb_dns_name}" },
        { name = "NODE_ENV", value = "development" } # using development for simplicity 
      ]
      readonly_root_filesystem = false # for alowing sqllite to work as no percistence needed
    }
  }

  ignore_task_definition_changes = false

  tags = local.tags
}

output "alb_dns_name" {
  description = "The Ghost site is running on this URL"
  value       = "http://${module.alb_ghost.lb_dns_name}"
}
