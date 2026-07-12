# --- Log Groups ---
resource "aws_cloudwatch_log_group" "trigger_lambda" {
  name              = "/aws/lambda/rapid-review-s3-trigger"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "worker_lambda" {
  name              = "/aws/lambda/doc-worker-func"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = "/ecs/rapid-review-api-task"
  retention_in_days = 14
}

# --- SNS Topic for Alerts ---
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- Alarm 1: ECS CPU Spike ---
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.project_name}-ecs-cpu-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60 # 1 minute
  statistic           = "Average"
  threshold           = 80 # 80% CPU
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

# --- Alarm 2: SQS Queue Backup ---
resource "aws_cloudwatch_metric_alarm" "sqs_backup" {
  alarm_name          = "${var.project_name}-sqs-backup"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesNotVisible"
  namespace           = "AWS/SQS"
  period              = 60 
  statistic           = "Average"
  threshold           = 50 # > 50 messages
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

# --- Alarm 3: DLQ Messages (P1 Incident) ---
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.project_name}-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0 # > 0 messages
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.dlq_name
  }
}

# --- CloudWatch Dashboard ---
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "ECS CPU Utilisation"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.sqs_queue_name]
          ]
          view    = "singleValue"
          region  = "us-east-1"
          title   = "SQS Queue Depth" #
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["RapidReview/API", "QueryLatency"] 
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Query Latency (p50 / p95)" #
          stat    = "p95"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_name]
          ]
          view    = "singleValue"
          region  = "us-east-1"
          title   = "DLQ Message Count" #
        }
      }
    ]
  })
}