# --- Pipeline Artifact S3 Bucket ---
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = var.artifact_bucket_name

  tags = {
    Name = "${var.project_name}-pipeline-artifacts"
  }
}

# --- CodeBuild Project ---
resource "aws_codebuild_project" "build" {
  name         = var.build_project_name
  service_role = "arn:aws:iam::523234425765:role/service-role/codebuild-rapid-review-build-service-role" 

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type         = "LINUX_CONTAINER"
  }

  source {
    type = "GITHUB"
  }

  lifecycle {
    ignore_changes = [
      environment,
      source,
      artifacts,
      service_role,
      vpc_config
    ]
  }
}

# --- CodePipeline ---
resource "aws_codepipeline" "main" {
  name     = var.pipeline_name
  role_arn = "arn:aws:iam::523234425765:role/service-role/AWSCodePipelineServiceRole-us-east-1-rapid-review-pipeline" 
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        S3Bucket = aws_s3_bucket.codepipeline_bucket.bucket
        S3ObjectKey = "dummy.zip"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = var.build_project_name
      }
    }
  }

  lifecycle {
    ignore_changes = [
      stage,
      role_arn
    ]
  }
}