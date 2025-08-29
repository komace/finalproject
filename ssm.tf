# Секрети для Django
resource "aws_ssm_parameter" "django_secret_key" {
  name  = "/${var.project}/DJANGO_SECRET_KEY"
  type  = "SecureString"
  value = var.django_secret_key
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project}/DATABASE_PASSWORD"
  type  = "SecureString"
  value = var.db_password
}

# Несейкретні змінні як String
resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project}/DATABASE_NAME"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/${var.project}/DATABASE_USERNAME"
  type  = "String"
  value = var.db_user
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project}/DATABASE_HOST"
  type  = "String"
  value = aws_db_instance.postgres.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project}/DATABASE_PORT"
  type  = "String"
  value = tostring(aws_db_instance.postgres.port)
}