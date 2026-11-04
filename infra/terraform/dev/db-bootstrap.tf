resource "random_password" "aptraining_app_db" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "aptraining_app_db" {
  name                    = "${var.project_name}/${var.environment}/database/app-credentials"
  description             = "Login credentials used by the APTraining dev backend"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "aptraining_app_db" {
  secret_id = aws_secretsmanager_secret.aptraining_app_db.id
  secret_string = jsonencode({
    username = "aptraining_app"
    password = random_password.aptraining_app_db.result
  })
}

resource "aws_ecs_cluster" "dev" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_cloudwatch_log_group" "db_bootstrap" {
  name              = "/ecs/${var.project_name}-${var.environment}/db-bootstrap"
  retention_in_days = 7
}

output "ecs_cluster_name" {
  description = "ECS cluster for APTraining dev tasks"
  value       = aws_ecs_cluster.dev.name
}

output "aptraining_app_db_secret_arn" {
  description = "Secrets Manager ARN containing the APTraining application DB credentials"
  value       = aws_secretsmanager_secret.aptraining_app_db.arn
}
