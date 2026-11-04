
output "aws_account_id" {
  description = "AWS account used by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region used by Terraform"
  value       = data.aws_region.current.region
}

output "available_availability_zones" {
  description = "Availability zones available in the selected region"
  value       = data.aws_availability_zones.available.names
}

output "vpc_id" {
  description = "ID of the APTraining dev VPC"
  value       = aws_vpc.aptraining.id
}

output "subnet_ids" {
  description = "Subnet IDs grouped by their logical names"
  value = {
    for name, subnet in aws_subnet.aptraining : name => subnet.id
  }
}

output "rds_endpoint" {
  description = "Private DNS endpoint of the APTraining PostgreSQL database"
  value       = aws_db_instance.aptraining.address
}

output "rds_port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.aptraining.port
}

output "rds_database_name" {
  description = "Initial APTraining database name"
  value       = aws_db_instance.aptraining.db_name
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS-managed master password secret"
  value = try(
    aws_db_instance.aptraining.master_user_secret[0].secret_arn,
    null
  )
}

output "ecs_task_role_arn" {
  description = "IAM task role to attach to the APTraining backend ECS task definition"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "IAM execution role for pulling the backend image and writing task logs"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecr_backend_repository_url" {
  description = "URI of the private ECR repository for the APTraining dev backend"
  value       = aws_ecr_repository.backend_dev.repository_url
}
