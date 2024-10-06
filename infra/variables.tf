variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "container_image" {
  description = "Container image to be deployed on ECS"
  default     = "ghost:latest"
}

variable "container_port" {
  description = "Port on which the container is listening"
  default     = 2368
}
