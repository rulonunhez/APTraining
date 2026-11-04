variable "project_name" {
  description = "Project identifier used in AWS resource names"
  type        = string
  default     = "aptraining"
}

variable "aws_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for local use"
  type        = string
  default     = "aptraining-dev"
}

variable "aws_account_id" {
  description = "AWS account ID used to make the S3 bucket name unique"
  type        = string
  default     = "639920117896"
}
