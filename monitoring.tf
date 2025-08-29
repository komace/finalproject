############################################
# Monitoring & Alerts (SNS + CloudWatch)
############################################



# 1) SNS Topic для алертів
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
  tags = { Project = var.project }
}

# 2) Підписка e-mail (після apply підтвердь листом!)
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "komaceraul@gmail.com"
}

# 3) ALB 5xx помилки (сума за 5 хвилин > 5)
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-alb-5xx"
  alarm_description   = "ALB 5xx errors > 5 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# 4) ECS CPU > 80% (2 періоди підряд по 60с)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project}-ecs-cpu-high"
  alarm_description   = "ECS service average CPU > 80%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# 5) ECS Memory > 80% (2 періоди підряд по 60с)
resource "aws_cloudwatch_metric_alarm" "ecs_mem_high" {
  alarm_name          = "${var.project}-ecs-mem-high"
  alarm_description   = "ECS service average Memory > 80%"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# 6) RDS: підключень забагато (приклад поріг 50)
resource "aws_cloudwatch_metric_alarm" "rds_conn_high" {
  alarm_name          = "${var.project}-rds-connections-high"
  alarm_description   = "RDS connections > 50"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

####################
# Зручні Outputs
####################
output "sns_alerts_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic ARN for alerts"
}

output "alarms" {
  value = {
    alb_5xx    = aws_cloudwatch_metric_alarm.alb_5xx.alarm_name
    ecs_cpu    = aws_cloudwatch_metric_alarm.ecs_cpu_high.alarm_name
    ecs_memory = aws_cloudwatch_metric_alarm.ecs_mem_high.alarm_name
    rds_conn   = aws_cloudwatch_metric_alarm.rds_conn_high.alarm_name
  }
}