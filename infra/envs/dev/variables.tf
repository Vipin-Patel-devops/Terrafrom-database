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
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
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

# dev: smaller task sizing
variable "task_cpu" {
  type    = string
  default = "256"
}

variable "task_memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

# dev: smaller instance
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_password" {
  type      = string
  sensitive = true
  # Do NOT put a real value here. Pass via:
  #   TF_VAR_db_password=... terraform plan
  # or a secrets manager / CI secret.
}

# dev: shorter retention
variable "db_backup_retention_period" {
  type    = number
  default = 1
}

# dev: deletion protection OFF so the env is easy to tear down
variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "devops-assessment"
  }
}
