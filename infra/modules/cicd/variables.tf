variable "project_name" {
  description = "Base name for resources"
  type        = string
}

variable "pipeline_name" {
  description = "The exact name of your CodePipeline"
  type        = string
}

variable "build_project_name" {
  description = "The exact name of your CodeBuild project"
  type        = string
}

variable "artifact_bucket_name" {
  description = "The exact name of the S3 bucket CodePipeline uses for artifacts"
  type        = string
}