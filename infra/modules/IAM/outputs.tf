output "lambda_trigger_role_arn" {
  value = aws_iam_role.lambda_trigger.arn
}

output "lambda_worker_role_arn" {
  value = aws_iam_role.lambda_worker.arn
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}