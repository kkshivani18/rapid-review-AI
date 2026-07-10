# --- S3 Bucket ---

resource "aws_s3_bucket" "documents" {
  bucket = var.bucket_name

  tags = {
    Name = "${var.project_name}-documents"
  }
}

# --- SQS Dead Letter Queue ---

resource "aws_sqs_queue" "dlq" {
  name = "doc-processing-dlq"

  tags = {
    Name = "${var.project_name}-dlq"
  }
}

# --- SQS Main Queue ---

resource "aws_sqs_queue" "main" {
  name = "doc-processing-queue"
  
  # Links the main queue to the DLQ after 3 failed attempts
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.project_name}-queue"
  }
}