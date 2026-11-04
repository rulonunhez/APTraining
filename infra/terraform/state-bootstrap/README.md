# Terraform state bucket bootstrap

This small stack creates the APTraining S3 bucket used by the remote Terraform backends. Its state stays local so the bucket can be created before the remote backend exists. The repository ignores local Terraform state files.

From this directory, initialize Terraform, review the plan, then apply it. After the bucket exists, the dev and GitHub Actions stacks can initialize against their separate keys in that bucket.

The bucket has public access blocked, server-side encryption, and versioning. Keep its local state file backed up outside the repository.
