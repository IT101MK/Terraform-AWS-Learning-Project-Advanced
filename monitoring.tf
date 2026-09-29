# monitoring.tf
#
# Stage 2: CloudWatch monitoring for the fleet built in hosts.tf.
#
# Alarm count = 2 * host_count (one StatusCheckFailed + one CPUUtilization
# alarm per host). CloudWatch's Always Free tier includes 10 alarms per
# account, so host_count above 5 pushes you past it (5 hosts * 2 = 10 is
# the exact ceiling; 6+ hosts means paying for extra alarms, on top of the
# extra public-IPv4 charges already called out in variables.tf).

# StatusCheckFailed catches "the instance or the underlying hardware has a
# problem" - AWS's own health check, not something we compute ourselves.
resource "aws_cloudwatch_metric_alarm" "status_check" {
  for_each = toset(local.host_keys)

  alarm_name          = "${var.project_name}-host-${each.key}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers when host ${each.key} fails an AWS status check (instance or system level)."
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = module.host[each.key].instance_id
  }

  # Splat expression, not a ternary indexing [0]: when the SNS topic's
  # count is 0 (notifications disabled), aws_sns_topic.alarms[*].arn just
  # evaluates to an empty list - no "index out of range" error the way
  # aws_sns_topic.alarms[0].arn would give even inside a false branch.
  alarm_actions = aws_sns_topic.alarms[*].arn

  tags = {
    Name = "${var.project_name}-host-${each.key}-status-check-failed"
  }
}

# CPUUtilization uses the threshold from variables.tf so it's tunable
# without editing this file.
resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = toset(local.host_keys)

  alarm_name          = "${var.project_name}-host-${each.key}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "Triggers when host ${each.key}'s average CPU exceeds ${var.cpu_alarm_threshold}% for two consecutive 5-minute periods."
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = module.host[each.key].instance_id
  }

  alarm_actions = aws_sns_topic.alarms[*].arn

  tags = {
    Name = "${var.project_name}-host-${each.key}-high-cpu"
  }
}

# One dashboard covering the whole fleet. Built with jsonencode() rather
# than hand-written JSON so Terraform expressions (the for loop below) can
# generate one widget per host instead of copy-pasting a widget block per
# instance.
resource "aws_cloudwatch_dashboard" "fleet" {
  dashboard_name = "${var.project_name}-fleet"

  dashboard_body = jsonencode({
    widgets = [
      for i, key in local.host_keys : {
        type   = "metric"
        x      = (i % 2) * 12
        y      = floor(i / 2) * 6
        width  = 12
        height = 6
        properties = {
          title  = "Host ${key} - CPU & Status Check"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", module.host[key].instance_id, { label = "CPU % (host ${key})" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", module.host[key].instance_id, { label = "Status check failed (host ${key})", yAxis = "right" }]
          ]
        }
      }
    ]
  })
}

# SNS topic + subscription, both gated behind enable_alarm_notifications.
# Using count (0 or 1) rather than a resource that always exists means
# "false" really does mean "nothing SNS-related gets created" - no empty
# topic left lying around when you don't want notifications.
resource "aws_sns_topic" "alarms" {
  count = var.enable_alarm_notifications ? 1 : 0

  name = "${var.project_name}-alarms"

  tags = {
    Name = "${var.project_name}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.enable_alarm_notifications ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
