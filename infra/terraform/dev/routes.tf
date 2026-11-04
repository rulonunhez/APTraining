
resource "aws_internet_gateway" "aptraining" {
  vpc_id = aws_vpc.aptraining.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.aptraining.id

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.aptraining.id
}

resource "aws_route_table_association" "public" {
  for_each = toset(["public_a", "public_b"])

  subnet_id      = aws_subnet.aptraining[each.value].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.aptraining.id

  tags = {
    Name = "${var.project_name}-${var.environment}-database-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = toset(["db_a", "db_b"])

  subnet_id      = aws_subnet.aptraining[each.value].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.aptraining.id

  tags = {
    Name = "${var.project_name}-${var.environment}-app-rt"
  }
}

resource "aws_route_table_association" "app" {
  for_each = toset(["app_a", "app_b"])

  subnet_id      = aws_subnet.aptraining[each.value].id
  route_table_id = aws_route_table.app.id
}
