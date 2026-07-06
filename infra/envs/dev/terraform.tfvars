aws_region   = "ap-south-1"
project_name = "hotelbooking"
environment  = "dev"

vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]
azs                  = ["ap-south-1a", "ap-south-1b"]

container_image = "nginx:latest"
container_port  = 80
task_cpu        = "256"
task_memory     = "512"
desired_count   = 1

db_engine                  = "postgres"
db_instance_class          = "db.t3.micro"
db_backup_retention_period = 1
db_deletion_protection     = false
db_password = "SomeStrongPassword123!"

# db_password intentionally NOT set here — pass via TF_VAR_db_password
# or CI secret. Never commit real secrets to tfvars.

tags = {
  Owner = "devops-assessment"
}
