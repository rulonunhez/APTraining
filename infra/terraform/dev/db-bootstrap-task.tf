resource "aws_ecs_task_definition" "db_bootstrap" {
  family                   = "${var.project_name}-${var.environment}-db-bootstrap"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name       = "db-bootstrap"
    image      = "public.ecr.aws/docker/library/postgres:15-alpine"
    essential  = true
    entryPoint = ["sh", "-c"]
    command = [<<-SCRIPT
      set -eu
      export PGPASSWORD="$DB_MASTER_PASSWORD"
      psql --set ON_ERROR_STOP=1 --host "$DB_HOST" --username "$DB_MASTER_USERNAME" --dbname "$DB_NAME" <<'SQL'
      \getenv app_password APP_DB_PASSWORD
      SELECT format('CREATE ROLE aptraining_app LOGIN PASSWORD %L', :'app_password')
      WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'aptraining_app')
      \gexec
      ALTER ROLE aptraining_app LOGIN PASSWORD :'app_password';
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      GRANT CONNECT ON DATABASE aptraining TO aptraining_app;
      GRANT USAGE, CREATE ON SCHEMA public TO aptraining_app;
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aptraining_app;
      GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO aptraining_app;
      SQL
    SCRIPT
    ]
    environment = [
      { name = "DB_HOST", value = aws_db_instance.aptraining.address },
      { name = "DB_NAME", value = aws_db_instance.aptraining.db_name },
    ]
    secrets = [
      {
        name      = "DB_MASTER_USERNAME"
        valueFrom = "${aws_db_instance.aptraining.master_user_secret[0].secret_arn}:username::"
      },
      {
        name      = "DB_MASTER_PASSWORD"
        valueFrom = "${aws_db_instance.aptraining.master_user_secret[0].secret_arn}:password::"
      },
      {
        name      = "APP_DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.aptraining_app_db.arn}:password::"
      },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.db_bootstrap.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "db-bootstrap"
      }
    }
  }])

  tags = {
    Name    = "${var.project_name}-${var.environment}-db-bootstrap"
    Purpose = "Initialize the APTraining application database login"
  }
}

output "db_bootstrap_task_definition_arn" {
  description = "Fargate task definition used to initialize the APTraining application DB login"
  value       = aws_ecs_task_definition.db_bootstrap.arn
}

output "app_security_group_id" {
  description = "Security group for private APTraining application tasks"
  value       = aws_security_group.app.id
}
