terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "aptraining-tfstate-639920117896-eu-north-1"
    key          = "aptraining/dev/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}
