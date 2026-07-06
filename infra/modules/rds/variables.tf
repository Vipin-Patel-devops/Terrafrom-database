variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type        = string
  description = "Only this SG is allowed to reach RDS on the DB port"
}

variable "engine" {
  type        = string
  description = "postgres or mysql"
  default     = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.3"
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "hotel_bookings"
}

variable "db_username" {
  type      = string
  default   = "hotel_admin"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
  description = "Pass via TF_VAR_db_password env var or a secrets manager, never commit in tfvars"
}

variable "backup_retention_period" {
  type        = number
  description = "Days to retain automated backups"
}

variable "deletion_protection" {
  type        = bool
  description = "Prevent accidental deletion (true in prod)"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
