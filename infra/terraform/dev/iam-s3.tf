data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name    = "${var.project_name}-${var.environment}-ecs-task-role"
    Purpose = "Runtime permissions for the APTraining backend task"
  }
}

data "aws_iam_policy_document" "ecs_task_s3_media" {
  statement {
    sid    = "ManageAPTrainingMediaObjects"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.media_dev.arn}/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_s3_media" {
  name   = "${var.project_name}-${var.environment}-s3-media-access"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_s3_media.json
}
