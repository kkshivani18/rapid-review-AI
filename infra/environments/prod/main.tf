module "networking" {
  source       = "../../modules/networking"
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
}

module "storage" {
  source       = "../../modules/storage"
  project_name = var.project_name
  bucket_name  = "docs-review-storage-523234425765-us-east-1-an" 
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
}

module "compute" {
  source = "../../modules/compute"
  
  project_name      = var.project_name
  private_subnet_id = module.networking.private_subnet_1a_id
  sg_qdrant_id      = module.networking.sg_qdrant_id
  sg_worker_id      = module.networking.sg_worker_id
  
  trigger_role_arn  = module.iam.lambda_trigger_role_arn
  worker_role_arn   = module.iam.lambda_worker_role_arn
}

module "ecs_api" {
  source = "../../modules/ecs_api"
  
  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  public_subnets     = [module.networking.public_subnet_1a_id, module.networking.public_subnet_1b_id]
  private_subnets    = [module.networking.private_subnet_1a_id]
  sg_ecs_id          = module.networking.sg_ecs_id
  sg_alb_id          = module.networking.sg_alb_id
  execution_role_arn = module.iam.ecs_execution_role_arn
}