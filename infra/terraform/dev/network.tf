
locals {
  dev_azs = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count
  )

  subnet_definitions = {
    public_a = {
      cidr_block = "10.20.1.0/24"
      az_index   = 0
      tier       = "public"
    }
    public_b = {
      cidr_block = "10.20.2.0/24"
      az_index   = 1
      tier       = "public"
    }
    app_a = {
      cidr_block = "10.20.11.0/24"
      az_index   = 0
      tier       = "application"
    }
    app_b = {
      cidr_block = "10.20.12.0/24"
      az_index   = 1
      tier       = "application"
    }
    db_a = {
      cidr_block = "10.20.21.0/24"
      az_index   = 0
      tier       = "database"
    }
    db_b = {
      cidr_block = "10.20.22.0/24"
      az_index   = 1
      tier       = "database"
    }
  }
}

resource "aws_vpc" "aptraining" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "aptraining" {
  for_each = local.subnet_definitions

  vpc_id            = aws_vpc.aptraining.id
  cidr_block        = each.value.cidr_block
  availability_zone = local.dev_azs[each.value.az_index]

  # No public IPs are assigned automatically.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}"
    Tier = each.value.tier
  }
}
