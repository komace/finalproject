# Змінні
variable "image_uri" {
  type = string
} # наприклад: 8572...dkr.ecr.eu-central-1.amazonaws.com/django-app:latest

variable "desired_count" {
  type    = number
  default = 1
}

variable "container_port" {
  type    = number
  default = 8000
}

resource "aws_ecs_cluster" "app" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project}-cluster" }
}


# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # якщо образ amd64 — заміни на X86_64
  }

  container_definitions = jsonencode([
    {
      name         = "web"
      image        = var.image_uri
      essential    = true
      portMappings = [{ containerPort = var.container_port, hostPort = var.container_port, protocol = "tcp" }]
      environment = [
        { name = "DEBUG", value = "False" },
        { name = "DJANGO_ALLOWED_HOSTS", value = "*" },
        { name = "DATABASE_ENGINE", value = "postgresql" }
      ]
      secrets = [
        { name = "DJANGO_SECRET_KEY", valueFrom = aws_ssm_parameter.django_secret_key.arn },
        { name = "DATABASE_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
        { name = "DATABASE_NAME", valueFrom = aws_ssm_parameter.db_name.arn },
        { name = "DATABASE_USERNAME", valueFrom = aws_ssm_parameter.db_user.arn },
        { name = "DATABASE_HOST", valueFrom = aws_ssm_parameter.db_host.arn },
        { name = "DATABASE_PORT", valueFrom = aws_ssm_parameter.db_port.arn }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
      # Якщо робиш міграції у entrypoint — лишай як є
      # command = ["sh", "-c", "python manage.py migrate --noinput && gunicorn django_app.wsgi:application -b 0.0.0.0:8000 --workers 2"]
    }
  ])
}

# ECS Service у приватних сабнетах за ALB
resource "aws_ecs_service" "app" {
  name             = "${var.project}-svc"
  cluster          = aws_ecs_cluster.app.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_target" {
  name               = "${var.project}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}