provider "aws" {
  region = var.aws_region
}

locals {
  name = "core-infra"
  tags = {
    Blueprint = local.name
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "ecs-alb-vpc" # use variable
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "alb_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "alb-sg" # use variable
  description = "Allow HTTP traffic for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0" # Allow all incoming HTTP traffic
      description = "Allow HTTP from anywhere"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0" # Allow all outbound traffic
      description = "Allow all outbound traffic"
    }
  ]

  tags = local.tags
}

module "ecs_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "ecs-sg" # use variable
  description = "Allow traffic from ALB to ECS"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 2368
      to_port                  = 2368
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id # Allow traffic from ALB only
      description              = "Allow traffic from ALB on port 2368"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0" # Allow all outbound traffic
      description = "Allow all outbound traffic"
    }
  ]

  tags = local.tags
}




module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "ecs-alb" # use variable
  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id] # Use security group module

  http_tcp_listeners = [{
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }]

  target_groups = [
    {
      name_prefix      = "ecs-tg"
      backend_protocol = "HTTP"
      backend_port     = 2368
      target_type      = "ip"
      health_check = {
        path = "/"
      }
    }
  ]

  tags = local.tags
}


module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "ghost-ecs-cluster" # use variable
  tags         = local.tags
}

module "ecs_service_definition" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name               = "ghost-service" # use variable
  desired_count      = 2
  cluster_arn        = module.ecs.cluster_arn
  enable_autoscaling = true
  cpu                = 512
  memory             = 1024

  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.ecs_sg.security_group_id]

  load_balancer = [{
    container_name   = "ghost" # use variable
    container_port   = var.container_port
    target_group_arn = module.alb.target_group_arns[0]
  }]

  container_definitions = {
    ghost-service = {
      cpu       = 256
      memory    = 512
      name      = "ghost" # use variable
      image     = var.container_image
      essential = true

      port_mappings = [{
        protocol : "tcp",
        containerPort : var.container_port
      }]
      environment = [
         {name = "NODE_ENV", value = "development"} # using dev environment for simplicity
      ]
      readonly_root_filesystem = false
    }
  }

  ignore_task_definition_changes = false

  tags = local.tags
}
