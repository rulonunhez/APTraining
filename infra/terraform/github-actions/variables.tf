variable "aws_region" {
  description = "AWS region containing APTraining dev resources"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile; leave empty when using environment credentials"
  type        = string
  default     = "aptraining-dev"
}

variable "project_name" {
  description = "Project identifier used in AWS resource names and tags"
  type        = string
  default     = "aptraining"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy APTraining dev"
  type        = string
  default     = "rulonunhez/APTraining"
}

variable "github_branch" {
  description = "Only this branch may assume the GitHub Actions role"
  type        = string
  default     = "DEV_AWS"
}

variable "aws_account_id" {
  description = "AWS account that owns the APTraining dev resources"
  type        = string
  default     = "639920117896"
}
