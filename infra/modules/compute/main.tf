# --- Qdrant EC2 Instance ---
resource "aws_instance" "qdrant" {
  ami           = "ami-021fcc6a5dcbbe9fa" 
  instance_type = "t3.small"
  subnet_id     = var.private_subnet_id
  vpc_security_group_ids = [var.sg_qdrant_id]

  tags = {
    Name = "${var.project_name}-qdrant"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}
# --- Lambda: S3 Trigger ---
resource "aws_lambda_function" "trigger" {
  function_name = "rapid-review-s3-trigger" 
  role          = var.trigger_role_arn
  runtime       = "python3.12"
  handler       = "handler.handler"
  filename      = "dummy.zip"
  timeout       = 30             

  environment {
    variables = {
      SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/523234425765/doc-processing-queue"
    }
  }

  tags = {
    Name = "${var.project_name}-trigger"
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# --- Lambda: Worker ---
resource "aws_lambda_function" "worker" {
  function_name = "doc-worker-func" 
  role          = var.worker_role_arn
  package_type  = "Image"      
  image_uri     = "523234425765.dkr.ecr.us-east-1.amazonaws.com/rapid-review-worker:latest" 
  memory_size   = 3008           # <--- prevents OOM errors
  timeout       = 900            # <--- prevents timeouts

  environment {
    variables = {
      QDRANT_HOST = "10.0.2.155"
    }
  }

  vpc_config {
    subnet_ids         = [var.private_subnet_id]
    security_group_ids = [var.sg_worker_id]
  }

  tags = {
    Name = "${var.project_name}-worker"
  }

  lifecycle {
    ignore_changes = [image_uri]
  }
}