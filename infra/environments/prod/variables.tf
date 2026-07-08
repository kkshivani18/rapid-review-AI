variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
}

variable "project_name" {
  description = "Base name for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}