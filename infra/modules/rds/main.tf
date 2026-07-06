locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  port = var.engine == "mysql" ? 3306 : 5432
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-db-subnets" })
}

# RDS security group: no ingress except from the ECS/Fargate security group.
# This is what makes the DB "private and only accessible from ECS/Fargate".
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow DB traffic only from ECS/Fargate tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB access from ECS tasks only"
    from_port       = local.port
    to_port         = local.port
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rds-sg" })
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name_prefix}-db"
  engine         = var.engine == "mysql" ? "mysql" : "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = local.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Private: no public IP, and it lives in private subnets only.
  publicly_accessible = false

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  multi_az                  = var.multi_az
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_prefix}-final-snapshot" : null

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db" })
}
