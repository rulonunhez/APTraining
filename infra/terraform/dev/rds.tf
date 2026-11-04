
# Select an available PostgreSQL 15 minor version in this region.
data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = "15"
  latest  = true
}

# RDS must use private database subnets in two AZs.
resource "aws_db_subnet_group" "aptraining" {
  name        = "${var.project_name}-${var.environment}-db-subnets"
  description = "Private database subnets for APTraining dev"

  subnet_ids = [
    aws_subnet.aptraining["db_a"].id,
    aws_subnet.aptraining["db_b"].id,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnets"
  }
}

resource "aws_db_instance" "aptraining" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = "db.t3.micro"

  db_name  = var.project_name
  username = "aptraining_admin"
  port     = 5432

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.aptraining.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  manage_master_user_password = true

  backup_retention_period = 1
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = true
  apply_immediately          = false
  deletion_protection        = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }

  lifecycle {
    prevent_destroy = true
  }
}
