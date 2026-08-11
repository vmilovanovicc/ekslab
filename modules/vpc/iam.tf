# IAM resources for VPC Flow Logs.
# Only created when enable_flow_logs = true.

data "aws_iam_policy_document" "flow_logs_assume_role" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count              = var.enable_flow_logs ? 1 : 0
  name               = "${var.project}-${var.environment}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role[0].json
}

data "aws_iam_policy_document" "flow_logs_policy" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    # Scoped to the specific log group created by this module.
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/vpc/${var.project}-${var.environment}/flow-logs",
      "arn:aws:logs:*:*:log-group:/aws/vpc/${var.project}-${var.environment}/flow-logs:*",
    ]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count  = var.enable_flow_logs ? 1 : 0
  name   = "flow-logs-publish"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_policy[0].json
}
