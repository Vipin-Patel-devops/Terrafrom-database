variable "project_name" {
  type        = string
  description = "Short name used to prefix/tag resources"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for public subnets (one per AZ)"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDRs for private subnets (one per AZ)"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across"
}

variable "single_nat_gateway" {
  type        = bool
  description = "If true, use one shared NAT gateway (cheaper, less resilient). Use false in prod."
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
