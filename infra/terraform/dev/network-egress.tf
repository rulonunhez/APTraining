resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "dev" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.aptraining["public_a"].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.aptraining]
}

resource "aws_route" "app_nat_egress" {
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.dev.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.aptraining.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-gateway-endpoint"
  }
}
