# --- ECS Task Execution Role ---

resource "aws_iam_role" "ecs_execution" {
  name = "ecsTaskExecutionRole" 

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

# --- Lambda Trigger Role ---

resource "aws_iam_role" "lambda_trigger" {
  name = "rapid-review-trigger-role" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# --- Lambda Worker Role ---

resource "aws_iam_role" "lambda_worker" {
  name = "doc-worker-role" 

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}