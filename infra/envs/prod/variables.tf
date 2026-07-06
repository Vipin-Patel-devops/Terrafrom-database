variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "hotelbooking"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "container_image" {
  type    = string
  default = "nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

# prod: larger task sizing, more replicas for availability
variable "task_cpu" {
  type    = string
  default = "1024"
}

variable "task_memory" {
  type    = string
  default = "2048"
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

# prod: larger instance
variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "db_password" {
  type      = string
  sensitive = true
  # Do NOT put a real value here. Pass via:
  #   TF_VAR_db_password=... terraform plan
  # or a secrets manager / CI secret.
}

# prod: longer retention
variable "db_backup_retention_period" {
  type    = number
  default = 30
}

# prod: deletion protection ON — must be explicitly disabled to destroy
variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "devops-assessment"
  }
}
