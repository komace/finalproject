# SG для ALB (публічний HTTP)
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB public SG"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-alb-sg" }
}

# Дозволяємо HTTP з усього інтернету
resource "aws_vpc_security_group_ingress_rule" "alb_http_80" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Вихід будь-куди (ALB робитиме health‑checks і трафік до таргетів)
resource "aws_vpc_security_group_egress_rule" "alb_egress_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# SG для ECS (бекенд у приватних/публічних сабнетах — як вирішиш)
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg"
  description = "ECS tasks SG"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-ecs-sg" }
}

# Дозволяємо трафік на порт додатка (8000) лише з ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_8000" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

# Вихід будь-куди (до RDS, SSM, зовн. сервісів — якщо ECS у публічних сабнетах)
resource "aws_vpc_security_group_egress_rule" "ecs_egress_all" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# SG для RDS (у приватних сабнетах)
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS Postgres SG"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-rds-sg" }
}

# Дозволяємо Postgres тільки з ECS
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs_5432" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}