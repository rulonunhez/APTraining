output "github_actions_deploy_role_arn" {
  description = "Set this ARN as the GitHub Actions repository variable AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "IAM OIDC provider used by GitHub Actions"
  value       = data.aws_iam_openid_connect_provider.github.arn
}
