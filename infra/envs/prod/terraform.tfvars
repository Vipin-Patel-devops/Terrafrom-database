aws_region   = "ap-south-1"
project_name = "hotelbooking"
environment  = "prod"

vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
azs                  = ["ap-south-1a", "ap-south-1b"]

container_image = "nginx:latest"
container_port  = 80
task_cpu        = "1024"
task_memory     = "2048"
desired_count   = 2

db_engine                  = "postgres"
db_instance_class          = "db.r6g.large"
db_backup_retention_period = 30
db_password = "SomeStrongPassword123!"
db_deletion_protection     = true

# db_password intentionally NOT set here — pass via TF_VAR_db_password
# or CI secret. Never commit real secrets to tfvars.

tags = {
  Owner = "devops-assessment"
}
