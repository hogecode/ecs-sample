# ========================================
# Auto Scaling Module Variables
# ========================================

variable "autoscaling_group_name" {
  description = "Auto Scaling group name"
  type        = string
}

variable "min_size" {
  description = "Minimum size of the Auto Scaling group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling group"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired capacity of the Auto Scaling group"
  type        = number
  default     = 2
}

variable "vpc_zone_identifier" {
  description = "Subnet IDs for the Auto Scaling group"
  type        = list(string)
  default     = []
}

variable "target_group_arns" {
  description = "Target group ARNs"
  type        = list(string)
  default     = []
}

variable "health_check_type" {
  description = "Health check type"
  type        = string
  default     = "ELB"
}

variable "health_check_grace_period" {
  description = "Health check grace period"
  type        = number
  default     = 300
}

variable "launch_template_name" {
  description = "Launch template name"
  type        = string
  default     = ""
}

variable "launch_template_version" {
  description = "Launch template version"
  type        = string
  default     = "$Latest"
}

variable "enabled_metrics" {
  description = "Enabled metrics"
  type        = list(string)
  default     = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
}

variable "metrics_granularity" {
  description = "Metrics granularity"
  type        = string
  default     = "1Minute"
}

variable "termination_policies" {
  description = "Termination policies"
  type        = list(string)
  default     = ["Default"]
}

variable "capacity_rebalance" {
  description = "Enable capacity rebalancing"
  type        = bool
  default     = false
}

variable "enable_scale_up_policy" {
  description = "Enable scale up policy"
  type        = bool
  default     = true
}

variable "enable_scale_down_policy" {
  description = "Enable scale down policy"
  type        = bool
  default     = true
}

variable "scale_up_adjustment" {
  description = "Scale up adjustment"
  type        = number
  default     = 1
}

variable "scale_down_adjustment" {
  description = "Scale down adjustment"
  type        = number
  default     = -1
}

variable "scale_cooldown" {
  description = "Scale cooldown"
  type        = number
  default     = 300
}

variable "scale_up_threshold" {
  description = "Scale up threshold (CPU percentage)"
  type        = number
  default     = 70
}

variable "scale_down_threshold" {
  description = "Scale down threshold (CPU percentage)"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
