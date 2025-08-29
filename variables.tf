variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "django-app"
}

variable "enable_nat" {
  type    = bool
  default = true
}

variable "db_name" {
  type    = string
  default = "polls"
}

variable "db_user" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  type = string
} # задаємо через tfvars

variable "django_secret_key" {
  type = string
}