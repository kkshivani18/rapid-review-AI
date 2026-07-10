# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api-task" 
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = "arn:aws:iam::523234425765:role/ecs_task_role"

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "api-container"
    image     = "dummy-image:latest"
    essential = true
    portMappings = [{
      containerPort = 8000
      protocol      = "tcp"
    }]
  }])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# --- ECS Service ---
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-service" 
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [
      task_definition, 
      desired_count,
      load_balancer,              
      deployment_circuit_breaker  
    ]
  }
}