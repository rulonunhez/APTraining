data "aws_iam_policy_document" "ecs_execution" {
  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullAPTrainingBackendImage"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]

    resources = [aws_ecr_repository.backend_dev.arn]
  }

  statement {
    sid    = "WriteAPTrainingTaskLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.backend.arn}:*"]
  }

  statement {
    sid     = "ReadAPTrainingDatabaseCredentials"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.aptraining_app_db.arn,
      aws_secretsmanager_secret.aptraining_jwt.arn,
    ]
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project_name}-${var.environment}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name    = "${var.project_name}-${var.environment}-ecs-execution-role"
    Purpose = "Pull the APTraining backend image and publish task logs"
  }
}

resource "aws_iam_role_policy" "ecs_execution" {
  name   = "${var.project_name}-${var.environment}-ecs-execution-policy"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution.json
}
