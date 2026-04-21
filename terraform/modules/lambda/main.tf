# ========================================
# Lambda Module - Using terraform-aws-lambda module
# ========================================

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 6.0"

  function_name = var.lambda_function_name
  description   = var.lambda_description
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  
  # Source code
  source_path = var.lambda_source_path
  
  # Environment variables
  environment_variables = var.environment_variables

  # Timeout and memory
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  # VPC configuration (optional)
  vpc_subnet_ids         = var.vpc_subnet_ids
  vpc_security_group_ids = var.vpc_security_group_ids

  # IAM role and policies
  role_name                     = "${var.lambda_function_name}-role"
  attach_cloudwatch_logs_policy = true
  cloudwatch_logs_retention_in_days = var.logs_retention_days

  # Attach VPC policy if needed
  attach_network_policy = length(var.vpc_subnet_ids) > 0 ? true : false

  # Attach additional policies
  attach_policy_statements = length(var.policy_statements) > 0 ? true : false
  policy_statements        = var.policy_statements

  # Reserved concurrent executions (optional)
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Layers (optional)
  layers = var.lambda_layers

  # Tags
  tags = var.common_tags
}

# ========================================
# Lambda EventBridge Rule (if triggered by events)
# ========================================

resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  count               = var.enable_event_trigger ? 1 : 0
  name                = "${var.lambda_function_name}-trigger"
  description         = "Trigger for ${var.lambda_function_name}"
  schedule_expression = var.event_schedule_expression
  
  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count      = var.enable_event_trigger ? 1 : 0
  rule       = aws_cloudwatch_event_rule.lambda_trigger[0].name
  target_id  = "LambdaTarget"
  arn        = module.lambda_function.lambda_function_arn
  input_path = var.event_input_path
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_event_trigger ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_trigger[0].arn
}
