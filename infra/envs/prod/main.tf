terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Separate state per environment. Fill in a real bucket/table before
  # running `terraform init` against real AWS, or comment this block out
  # and use local state for a first dry-run (`terraform plan` only needs
  # a backend if you actually run `init` against remote state).
  backend "s3" {
    bucket         = "hotelbooking-tfstate-prod-73921"
    key            = "hotel-booking/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotelbooking-tflocks-prod"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
  single_nat_gateway   = false # prod: one NAT per AZ for resilience
  tags                 = var.tags
}

module "ecs" {
  source = "../../modules/ecs"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  container_image    = var.container_image
  container_port     = var.container_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  tags               = var.tags
}

module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  ecs_security_group_id   = module.ecs.ecs_security_group_id
  engine                  = var.db_engine
  instance_class          = var.db_instance_class
  db_password             = var.db_password
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  multi_az                = true # prod: multi-AZ for HA
  tags                    = var.tags
}
