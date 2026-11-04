
variable "aws_region" {
  description = "AWS region for APTraining dev"
  type        = string
  default     = "eu-north-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile for local use; leave empty when using environment credentials such as GitHub OIDC"
  type        = string
  default     = "aptraining-dev"
}

variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
  default     = "aptraining"
}

variable "aws_account_id" {
  description = "AWS account ID used in globally unique S3 bucket names"
  type        = string
  default     = "639920117896"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "backend_image_tag" {
  description = "ECR tag used by the APTraining dev backend task definition"
  type        = string
  default     = "dev-20261022-02"
}

variable "enable_demo_api" {
  description = "Create the on-demand HTTPS API Gateway, VPC Link, internal ALB, and ECS service for demos"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the APTraining dev VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones used by the dev network"
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count == 2
    error_message = "The dev network is currently designed for exactly two availability zones."
  }
}
