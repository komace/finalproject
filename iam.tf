data "aws_caller_identity" "current" {}

# Trust policy для ECS Tasks (assume role)
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# -------- Execution Role (тягне образ з ECR, пише логи, ЧИТАЄ SSM секрети) --------
resource "aws_iam_role" "ecs_execution" {
  name               = "${var.project}-ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# Стандартний managed-полісі для ECR/CloudWatch Logs
resource "aws_iam_role_policy_attachment" "exec_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Дозволяємо читати параметри з SSM (у префіксі /<project>/*) + KMS decrypt для SecureString
resource "aws_iam_role_policy" "ecs_exec_ssm" {
  name = "${var.project}-ecs-exec-ssm"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReadSSMParameters",
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/*"
        ]
      },
      {
        Sid    = "AllowKmsDecryptForSecureString",
        Effect = "Allow",
        Action = ["kms:Decrypt"],
        Resource = [
          # керований AWS ключ для SSM Parameter Store
          "arn:aws:kms:${var.aws_region}:*:alias/aws/ssm",
          # або кастомні ключі акаунта, якщо раптом використовуватимеш
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}

# -------- Task Role (права додатку усередині контейнера) --------
resource "aws_iam_role" "ecs_task" {
  name               = "${var.project}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# (Опційно) якщо додатку в контейнері теж потрібен доступ до SSM чи інших сервісів — додамо окремі політики сюди пізніше.

############################
# Outputs (зручно для підстановок)
############################
output "ecs_execution_role_arn" {
  value       = aws_iam_role.ecs_execution.arn
  description = "ECS Execution Role ARN"
}

output "ecs_task_role_arn" {
  value       = aws_iam_role.ecs_task.arn
  description = "ECS Task Role ARN"
}