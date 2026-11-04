data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = "${var.project_name}-${var.environment}-github-actions-deploy"
  description          = "Build and deploy APTraining dev from the protected main branch"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume_role.json
  max_session_duration = 3600

  tags = {
    Name      = "${var.project_name}-${var.environment}-github-actions-deploy"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "TerraformStateBucketMetadata"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:GetBucketVersioning", "s3:ListBucket"]
    resources = ["arn:aws:s3:::aptraining-tfstate-639920117896-eu-north-1"]
  }

  statement {
    sid    = "ReadAndWriteTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::aptraining-tfstate-639920117896-eu-north-1/aptraining/dev/terraform.tfstate"]
  }

  statement {
    sid    = "ManageTerraformStateLock"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::aptraining-tfstate-639920117896-eu-north-1/aptraining/dev/terraform.tfstate.tflock"]
  }

  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushAPTrainingBackendImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project_name}-backend-${var.environment}"]
  }

  statement {
    sid    = "ReadExistingAPTrainingInfrastructure"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "ec2:Describe*",
      "ecs:Describe*",
      "ecs:List*",
      "ecr:DescribeImages",
      "ecr:GetLifecyclePolicy",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "elasticloadbalancing:Describe*",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadAPTrainingIamRoles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = ["arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-*"]
  }

  statement {
    sid    = "ReadAPTrainingSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.project_name}/${var.environment}/*"]
  }

  statement {
    sid    = "ReadAPTrainingMediaBucketConfiguration"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::${var.project_name}-media-${var.environment}-${var.aws_account_id}"]
  }

  statement {
    sid       = "CreateDemoSecurityGroup"
    effect    = "Allow"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid       = "DeleteOnlyAPTrainingSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:DeleteSecurityGroup"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "AddIngressOnlyToAPTrainingSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "TagIngressRulesOnlyForAPTraining"
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group-rule/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "AddEgressOnlyToAPTrainingSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupEgress"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "RevokeEgressOnlyOnAPTrainingSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:RevokeSecurityGroupEgress"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "TagAPTrainingResources"
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "CreateTaggedDemoLoadBalancerResources"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "CreateListenerOnlyForAPTrainingDemoLoadBalancer"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:CreateListener"]
    resources = ["arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:loadbalancer/app/${var.project_name}-${var.environment}-api/*"]
  }

  statement {
    sid     = "UpdateDemoLoadBalancerResources"
    effect  = "Allow"
    actions = ["elasticloadbalancing:AddTags"]
    resources = [
      "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:loadbalancer/app/${var.project_name}-${var.environment}-api/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:listener/app/${var.project_name}-${var.environment}-api/*/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:targetgroup/${var.project_name}-${var.environment}-backend/*",
    ]
  }

  statement {
    sid       = "ModifyOnlyAPTrainingDemoLoadBalancer"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:ModifyLoadBalancerAttributes"]
    resources = ["arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:loadbalancer/app/${var.project_name}-${var.environment}-api/*"]
  }

  statement {
    sid       = "ModifyOnlyAPTrainingDemoListener"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:ModifyListener"]
    resources = ["arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:listener/app/${var.project_name}-${var.environment}-api/*/*"]
  }

  statement {
    sid       = "ModifyOnlyAPTrainingDemoTargetGroup"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:ModifyTargetGroupAttributes"]
    resources = ["arn:aws:elasticloadbalancing:${var.aws_region}:${var.aws_account_id}:targetgroup/${var.project_name}-${var.environment}-backend/*"]
  }

  statement {
    sid     = "CreateDemoHttpApiResources"
    effect  = "Allow"
    actions = ["apigateway:POST"]
    resources = [
      "arn:aws:apigateway:${var.aws_region}::/apis",
      "arn:aws:apigateway:${var.aws_region}::/apis/*/integrations",
      "arn:aws:apigateway:${var.aws_region}::/apis/*/routes",
      "arn:aws:apigateway:${var.aws_region}::/apis/*/stages",
      "arn:aws:apigateway:${var.aws_region}::/tags/*",
      "arn:aws:apigateway:${var.aws_region}::/vpclinks",
    ]
  }

  statement {
    sid    = "TagDemoHttpApiResources"
    effect = "Allow"
    actions = [
      "apigateway:PATCH",
      "apigateway:TagResource",
    ]
    resources = [
      "arn:aws:apigateway:${var.aws_region}::/apis/*",
      "arn:aws:apigateway:${var.aws_region}::/apis/*/stages",
      "arn:aws:apigateway:${var.aws_region}::/apis/*/stages/*",
      "arn:aws:apigateway:${var.aws_region}::/vpclinks",
      "arn:aws:apigateway:${var.aws_region}::/vpclinks/*",
    ]
  }

  statement {
    sid    = "RegisterAPTrainingBackendTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${var.project_name}-${var.environment}-backend*"]
  }

  statement {
    sid       = "CreateServiceInAPTrainingDevCluster"
    effect    = "Allow"
    actions   = ["ecs:CreateService"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${var.project_name}-${var.environment}"]
    }
  }

  statement {
    sid       = "UpdateOnlyAPTrainingDemoService"
    effect    = "Allow"
    actions   = ["ecs:UpdateService"]
    resources = ["arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.project_name}-${var.environment}/${var.project_name}-${var.environment}-backend-demo"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${var.project_name}-${var.environment}"]
    }
  }

  statement {
    sid     = "TagAPTrainingEcsResources"
    effect  = "Allow"
    actions = ["ecs:TagResource"]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${var.project_name}-${var.environment}/${var.project_name}-${var.environment}-backend-demo",
      "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${var.project_name}-${var.environment}-backend*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "PassOnlyAPTrainingTaskRolesToEcs"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-ecs-*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.project_name}-${var.environment}-github-actions-deploy-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
