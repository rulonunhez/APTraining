# GitHub Actions OIDC deployment role

This stack creates the dedicated IAM role used by the APTraining deployment workflow. It uses the APTraining state bucket and a state key separate from the dev stack.

The trust policy accepts only repository `rulonunhez/APTraining` (owner ID `79594316`, repository ID `1445630187`) on branch `DEV_AWS`. It uses GitHub's immutable OIDC subject format for repositories created after July 15, 2026. The stack reads the account's existing GitHub OIDC provider; it does not create a second provider. Its inline policy is scoped to the Terraform state and lock file, the APTraining dev ECR image, running the database bootstrap task, reading the current dev stack, and creating or updating the optional demo API and ECS deployment. It does not grant permission to delete the Terraform state, VPC, RDS database, or media bucket, or to modify existing IAM roles.

## Provision the role from PowerShell

Sign in with the APTraining SSO profile, initialize the stack, and inspect the plan:

```powershell
aws sso login --profile aptraining-dev
$env:AWS_PROFILE = 'aptraining-dev'
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' init
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' plan
```

The plan should update the trust policy on the existing APTraining GitHub Actions role. It should read the already existing GitHub OIDC provider as a data source. Confirm that it does not propose creating an OIDC provider, replacing the role, or changing unrelated resources before applying:

```powershell
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' apply
terraform -chdir='C:\ProyectoGymApp\APTraining\infra\terraform\github-actions' output -raw github_actions_deploy_role_arn
```

Copy the resulting ARN. In GitHub, open **rulonunhez/APTraining → Settings → Secrets and variables → Actions → Variables → New repository variable** and create:

- Name: `AWS_DEPLOY_ROLE_ARN`
- Value: the ARN printed by Terraform

This ARN identifies the role and is not a credential. GitHub Actions exchanges its OIDC token for temporary AWS credentials.

## Deploy from `DEV_AWS`

The workflow runs on pushes to `DEV_AWS` that change `backend/**` or the workflow file. Before building and deploying the backend, it runs the database bootstrap task inside the VPC. The task definition must have been provisioned by applying the dev Terraform stack once with the local SSO profile. Once the repository variable is saved and the task definition exists, push the backend change from the local `DEV_AWS` branch:

```powershell
git switch DEV_AWS
git push -u origin DEV_AWS
```

The workflow builds and pushes the backend image, then applies the dev stack with `enable_demo_api=true`. This creates the demo API and ECS service and can add AWS charges. The deployment role trust policy does not allow `main` to assume the role. The workflow can also be manually started with **Actions → Deploy APTraining dev backend → Run workflow**, selecting `DEV_AWS`.

When retiring GymApp, retain the account-wide GitHub OIDC provider. Remove it from GymApp's old Terraform state before destroying the old bootstrap stack so Terraform does not delete the provider used by APTraining.
