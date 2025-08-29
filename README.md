# finalproject
django_app

# Django на AWS: ECS Fargate + ALB + RDS + ECR (Terraform)

## 1. Опис середовища
- **ECS (Fargate)** — запуск контейнера Django.
- **ALB** — балансувальник трафіку (HTTP:80).
- **RDS PostgreSQL** — керована БД у приватних сабнетах.
- **ECR** — приватний репозиторій образів.
- **VPC** — 2 public + 2 private сабнети, IGW, NAT.
- **SSM Parameter Store** — секрети (DB creds, DJANGO_SECRET_KEY).
- **CloudWatch + SNS** — моніторинг і алерти.
- **AWS Budgets** — бюджет і нотифікації.

## 2. Обґрунтування вибору
- **Fargate**: без серверів/EC2, проста експлуатація, автоскейлінг.
- **RDS**: керована Postgres, бекапи, менший опекс.
- **ALB**: масштабування та health-check.
- **ECR**: нативне сховище образів.
- **CloudWatch/SNS/Budgets**: моніторинг, алерти, контроль витрат.

## 3. Архітектурна схема
User → **ALB (public)** → **ECS Tasks (private)** → **RDS (private)**  
VPC: 2×public + 2×private AZ; SG: ALB(80←Internet), ECS(8000←ALB), RDS(5432←ECS).

## 4. Як деплоїти

### 4.1 Передумови
- Налаштований AWS CLI профіль: `my-aws`
- Регіон: `eu-central-1`
- Образ у ECR: `857241517212.dkr.ecr.eu-central-1.amazonaws.com/django-app:latest`

### 4.2 Terraform
```bash
cd terraform_django_app
cp terraform.tfvars.example terraform.tfvars   
terraform init
terraform apply

# Міграції(one-off task)
export AWS_PROFILE=my-aws
export REGION=eu-central-1
export PROJECT=django-app
export CLUSTER="${PROJECT}-cluster"
export FAMILY="${PROJECT}-task"
export CONTAINER_NAME="web"

TASK_DEF_ARN=$(aws ecs list-task-definitions --family-prefix "$FAMILY" --region "$REGION" --query 'taskDefinitionArns[-1]' --output text)
SUBNET_IDS_SPACE=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=tag:Name,Values=${PROJECT}-private-*" --query 'Subnets[].SubnetId' --output text)
SUBNET_IDS_CSV=$(echo "$SUBNET_IDS_SPACE" | sed 's/ /,/g')
ECS_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=group-name,Values=${PROJECT}-ecs-sg" --query 'SecurityGroups[0].GroupId' --output text)

aws ecs run-task \
  --region "$REGION" --cluster "$CLUSTER" --launch-type FARGATE \
  --task-definition "$TASK_DEF_ARN" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS_CSV],securityGroups=[$ECS_SG_ID],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"$CONTAINER_NAME\",\"command\":[\"python\",\"manage.py\",\"migrate\",\"--noinput\"]}]}"

# Перевірка доступності

terraform output -raw alb_dns_name
curl -I http://$(terraform output -raw alb_dns_name)  # HTTP/1.1 200 OK


## Моніторинг.алерти.автоскелінг - перевірки
# ECS Service
aws ecs describe-services --cluster "${PROJECT}-cluster" --services "${PROJECT}-svc" --region "$REGION" \
  --query 'services[0].{desired:desiredCount,running:runningCount,status:status}' --output table

# ALB Target Group healthy
TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "${PROJECT}-tg" --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$TG_ARN" --query 'TargetHealthDescriptions[].TargetHealth.State'

# Останні логи
aws logs describe-log-streams --region "$REGION" --log-group-name "/ecs/${PROJECT}" \
  --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text \
| xargs -I {} aws logs get-log-events --region "$REGION" --log-group-name "/ecs/${PROJECT}" --log-stream-name {} --limit 50 --output text