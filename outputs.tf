# VPC
output "vpc_id" {
  value = aws_vpc.main.id
}

# Subnets
output "public_subnet_ids" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

# Internet Gateway
output "igw_id" {
  value = aws_internet_gateway.igw.id
}

# Route tables
output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "nat_gateway_id" {
  value       = var.enable_nat ? aws_nat_gateway.nat[0].id : null
  description = "NAT GW ID (if enabled)"
}
output "nat_eip" {
  value       = var.enable_nat ? aws_eip.nat[0].public_ip : null
  description = "Elastic IP for NAT (if enabled)"
}

output "sg_alb_id" { value = aws_security_group.alb.id }
output "sg_ecs_id" { value = aws_security_group.ecs.id }
output "sg_rds_id" { value = aws_security_group.rds.id }

output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecr_repository_name" { value = aws_ecr_repository.app.name }

output "rds_endpoint" { value = aws_db_instance.postgres.address }
output "rds_port" { value = aws_db_instance.postgres.port }