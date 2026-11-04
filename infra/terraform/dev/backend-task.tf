resource "random_password" "aptraining_jwt" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "aptraining_jwt" {
  name                    = "${var.project_name}/${var.environment}/backend/jwt-signing-key"
  description             = "Base64 signing key used by APTraining dev JWT tokens"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "aptraining_jwt" {
  secret_id     = aws_secretsmanager_secret.aptraining_jwt.id
  secret_string = base64encode(random_password.aptraining_jwt.result)
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-${var.environment}/backend"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  skip_destroy             = true
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = "${aws_ecr_repository.backend_dev.repository_url}:${var.backend_image_tag}"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "AWS_S3_BUCKET", value = aws_s3_bucket.media_dev.id },
      { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.aptraining.address}:5432/${aws_db_instance.aptraining.db_name}?sslmode=require" },
    ]
    secrets = [
      {
        name      = "SPRING_DATASOURCE_USERNAME"
        valueFrom = "${aws_secretsmanager_secret.aptraining_app_db.arn}:username::"
      },
      {
        name      = "SPRING_DATASOURCE_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.aptraining_app_db.arn}:password::"
      },
      {
        name      = "JWT_SECRET"
        valueFrom = aws_secretsmanager_secret.aptraining_jwt.arn
      },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
  }
}

output "backend_task_definition_arn" {
  description = "ECS Fargate task definition ARN for the APTraining dev backend"
  value       = aws_ecs_task_definition.backend.arn
}

output "aptraining_jwt_secret_arn" {
  description = "Secrets Manager ARN containing the APTraining dev JWT signing key"
  value       = aws_secretsmanager_secret.aptraining_jwt.arn
}
