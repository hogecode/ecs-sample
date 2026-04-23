# ========================================
# Auto Scaling Module - Using terraform-aws-autoscaling module
# ========================================

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 7.0"

  name            = var.autoscaling_group_name
  min_size        = var.min_size
  max_size        = var.max_size
  desired_capacity = var.desired_capacity
  
  vpc_zone_identifier = var.vpc_zone_identifier
  target_group_arns  = var.target_group_arns
  health_check_type  = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  # Launch template
  launch_template_name    = var.launch_template_name
  launch_template_version = var.launch_template_version

  # Auto scaling policies
  enabled_metrics = var.enabled_metrics
  metrics_granularity = var.metrics_granularity

  # Termination policies
  termination_policies = var.termination_policies

  # Capacity rebalancing
  capacity_rebalance = var.capacity_rebalance

  # Tags
  tag_specifications = {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = var.autoscaling_group_name
    })
  }

  tags = var.common_tags
}

# ========================================
# Auto Scaling Policies
# ========================================

resource "aws_autoscaling_policy" "scale_up" {
  count                  = var.enable_scale_up_policy ? 1 : 0
  name                   = "${var.autoscaling_group_name}-scale-up"
  scaling_adjustment     = var.scale_up_adjustment
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.scale_cooldown
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
}

resource "aws_autoscaling_policy" "scale_down" {
  count                  = var.enable_scale_down_policy ? 1 : 0
  name                   = "${var.autoscaling_group_name}-scale-down"
  scaling_adjustment     = var.scale_down_adjustment
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.scale_cooldown
  autoscaling_group_name = module.autoscaling.autoscaling_group_name
}

# ========================================
# CloudWatch Alarms for Auto Scaling
# ========================================

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  count               = var.enable_scale_up_policy ? 1 : 0
  alarm_name          = "${var.autoscaling_group_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_up_threshold
  alarm_description   = "Trigger scaling up when CPU is high"
  alarm_actions       = [aws_autoscaling_policy.scale_up[0].arn]

  dimensions = {
    AutoScalingGroupName = module.autoscaling.autoscaling_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  count               = var.enable_scale_down_policy ? 1 : 0
  alarm_name          = "${var.autoscaling_group_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_down_threshold
  alarm_description   = "Trigger scaling down when CPU is low"
  alarm_actions       = [aws_autoscaling_policy.scale_down[0].arn]

  dimensions = {
    AutoScalingGroupName = module.autoscaling.autoscaling_group_name
  }
}
