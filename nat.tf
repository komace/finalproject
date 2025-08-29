# EIP для NAT (тільки якщо увімкнено NAT)
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.project}-nat-eip" }
}

# NAT Gateway у публічному сабнеті (наприклад, public_a)
resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "${var.project}-nat" }

  depends_on = [aws_internet_gateway.igw]
}

# Маршрут для приватної RT через NAT
resource "aws_route" "private_nat_access" {
  count                  = var.enable_nat ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}