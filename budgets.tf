resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project}-monthly-budget"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = "20"
  limit_unit   = "USD"

  # приклад фільтрів (опц.): рахуємо лише цей регіон
  # cost_filters = { Region = var.aws_region }

  # Прогнозовані витрати >80% бюджету -> SNS
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  # Фактичні витрати >100% бюджету -> SNS
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }
}