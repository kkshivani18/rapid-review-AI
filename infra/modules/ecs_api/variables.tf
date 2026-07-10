variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "sg_ecs_id" { type = string }
variable "sg_alb_id" { type = string }
variable "execution_role_arn" { type = string }