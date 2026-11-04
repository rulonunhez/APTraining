# Automated APTraining dev deployment

A push to `DEV_AWS` that changes `backend/` or this workflow builds the backend image, pushes it to ECR using the commit SHA and GitHub run attempt as its immutable tag, and runs Terraform with `enable_demo_api=true`. The ECS demo service and its public API endpoint will therefore be active after deployment. Terraform infrastructure changes themselves should be planned and applied locally with the SSO profile.

The Terraform files used by CI live in this repository at `infra/terraform/dev`. From the repository root, use the scripts below to deploy the latest image already pushed to ECR or stop the demo API:

```powershell
.\infra\terraform\dev\deploy-dev-api.ps1
.\infra\terraform\dev\stop-dev-api.ps1
```

The deploy script selects the newest tagged image in `aptraining-backend-dev`, shows a Terraform plan, and only applies it if you type `APLICAR`. To deploy a specific image, pass its ECR tag with `-BackendImageTag '<tag>'`.

The stop script keeps the backend image tag recorded in Terraform state, checks that the plan only deletes demo API resources, and only applies it if you type `APAGAR`. It does not delete persistent resources such as RDS or the media bucket.

Both scripts authenticate with the `aptraining-dev` AWS SSO profile by default and verify that it points to account `639920117896`. You can choose another profile with `-AwsProfile '<profile>'`.

The next qualifying push to `DEV_AWS` turns the demo back on because the GitHub Actions workflow applies with `enable_demo_api=true`.

## One-time setup still required

1. Apply the state-bucket bootstrap in `infra/terraform/state-bootstrap`, then initialize the dev and GitHub Actions stacks. Apply the GitHub Actions role stack after reviewing its plan. It reuses the account's existing GitHub OIDC provider and creates a role trusted only for `rulonunhez/APTraining` on `DEV_AWS`.
2. Add the resulting role ARN as the GitHub Actions repository variable `AWS_DEPLOY_ROLE_ARN`.

Protect `DEV_AWS` so only trusted contributors can push to it: each push that runs this workflow can publish a backend image and apply infrastructure changes in the AWS account.

The workflow uses OIDC and does not use long-lived AWS access keys. Do not enable the workflow until the role exists and its permissions have been reviewed. A Terraform apply failure after the image push leaves the new image in ECR but does not guarantee that ECS has deployed it.
