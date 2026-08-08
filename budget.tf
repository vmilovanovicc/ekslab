resource "aws_budgets_budget" "cost_guard" {
  count = var.enable_budget_alarm ? 1 : 0

  name         = "${var.project}-${var.environment}-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Fires as actual spend crosses the threshold within the month.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  # Fires early if forecasted spend is on track to exceed the limit,
  # catching a forgotten apply before it fully plays out.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }
}
