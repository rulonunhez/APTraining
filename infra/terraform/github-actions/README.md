# GitHub Actions OIDC deployment role

This stack creates the dedicated GitHub Actions deployment role. It uses the APTraining state bucket and a separate state key from the dev stack.

The trust policy accepts only the `rulonunhez/APTraining` repository on branch `DEV_AWS`. The inline policy is limited to the Terraform state and lock file, the APTraining dev ECR image, reading the current dev stack, and creating/updating the optional demo API and ECS deployment. It does not grant permission to delete the Terraform state, VPC, RDS database, or media bucket, or to modify existing IAM roles. The stack reads the account's existing GitHub OIDC provider instead of attempting to create a duplicate provider.

When the old GymApp bootstrap stack is retired, remove its OIDC provider from the old Terraform state without deleting the AWS provider itself. APTraining's deployment role uses that account-wide provider.

## Apply from PowerShell

Review the plan before applying it:

```powershell
$env:AWS_PROFILE = 'aptraining-dev'
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' init
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' plan
```

The expected plan creates an IAM OIDC provider, one deploy role, and its inline policy. If the provider already exists, stop and import it or adapt the stack to reference its ARN; do not try to create a duplicate. After reviewing the plan, apply it and retrieve the role ARN:

```powershell
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' apply
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' output -raw github_actions_deploy_role_arn
```

Add the output in the GitHub repository at **Settings → Secrets and variables → Actions → Variables** with the name `AWS_DEPLOY_ROLE_ARN`. It is an ARN, not a secret credential.

This role is intended for the existing deployment workflow, which always applies the stack with `enable_demo_api=true`. Apply unrelated foundational infrastructure changes locally using the SSO profile.
