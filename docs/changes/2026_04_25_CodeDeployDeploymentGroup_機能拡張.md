# CodeDeploy Deployment Group 機能拡張

## 概要
AWS Terraform Registry の `aws_codedeploy_deployment_group` リソースのドキュメントに基づいて、既存の CI/CD モジュール内の CodeDeploy Deployment Group を拡張・改善しました。

## 変更内容

### 1. 変数（variables.tf）の拡張

#### SNS トリガー設定
```hcl
variable "enable_deployment_triggers" {
  description = "Enable SNS triggers for deployment notifications"
  type        = bool
  default     = false
}

variable "deployment_trigger_sns_topic_arn" {
  description = "SNS topic ARN for deployment notifications"
  type        = string
  default     = ""
}
```
デプロイメント開始、成功、失敗などのイベントを SNS トピックに通知できます。

#### CloudWatch アラーム設定
```hcl
variable "enable_alarm_configuration" {
  description = "Enable CloudWatch alarm configuration for deployments"
  type        = bool
  default     = false
}

variable "alarm_names" {
  description = "List of CloudWatch alarm names to monitor during deployment"
  type        = list(string)
  default     = []
}

variable "ignore_poll_alarm_failure" {
  description = "Whether to ignore failure when CloudWatch alarms cannot be polled"
  type        = bool
  default     = false
}
```
CloudWatch アラームを監視して、指定した閾値を超えた場合にデプロイメントを停止できます。

#### ターゲットグループペア設定（高度な Blue/Green デプロイメント）
```hcl
variable "use_target_group_pair_info" {
  description = "Use target group pair info for more advanced load balancer configuration"
  type        = bool
  default     = false
}

variable "alb_listener_arns" {
  description = "List of ALB listener ARNs for target group pair configuration"
  type        = list(string)
  default     = []
}

variable "blue_green_test_traffic_route_listener_arns" {
  description = "List of ALB listener ARNs for test traffic route in blue/green deployments"
  type        = list(string)
  default     = []
}
```
ターゲットグループペア情報を使用して、本番トラフィックと テストトラフィックの経路を分離して制御できます。

#### Blue/Green デプロイメント制御
```hcl
variable "codedeploy_deployment_ready_action_on_timeout" {
  description = "The action to take when new Green instances are ready to receive traffic"
  type        = string
  default     = "CONTINUE_DEPLOYMENT"
  
  validation {
    condition     = contains(["CONTINUE_DEPLOYMENT", "STOP_DEPLOYMENT"], ...)
    error_message = "Action must be one of: CONTINUE_DEPLOYMENT, STOP_DEPLOYMENT"
  }
}

variable "codedeploy_termination_action" {
  description = "The action to take on instances after successful blue/green deployment"
  type        = string
  default     = "TERMINATE"
  
  validation {
    condition     = contains(["TERMINATE", "KEEP_ALIVE"], ...)
    error_message = "Action must be one of: TERMINATE, KEEP_ALIVE"
  }
}
```

### 2. リソース設定（main.tf）の拡張

#### ECS サービス設定（必須）
```hcl
# ECS Service Configuration (Required for ECS deployments)
ecs_service {
  cluster_name = var.ecs_cluster_name
  service_name = var.ecs_service_name
}
```
**重要**: ECS デプロイメント グループを作成する際には、ECS サービス設定が必須です。
`var.ecs_cluster_name` と `var.ecs_service_name` を必ず指定する必要があります。

この設定により、CodeDeploy は対象となる ECS クラスターとサービスを認識し、Blue/Green デプロイメントを実行できます。

#### Blue/Green デプロイメント設定ブロック
```hcl
blue_green_deployment_config {
  # Green インスタンスへのトラフィック切り替え制御
  deployment_ready_option {
    action_on_timeout    = var.codedeploy_deployment_ready_action_on_timeout
    wait_time_in_minutes = var.codedeploy_deployment_ready_wait_time_in_minutes
  }

  # Blue インスタンスの終了制御
  terminate_blue_instances_on_deployment_success {
    action                           = var.codedeploy_termination_action
    termination_wait_time_in_minutes = var.codedeploy_termination_wait_time_in_minutes
  }
}
```

#### 柔軟なロードバランサー設定
```hcl
load_balancer_info {
  # 高度な設定：ターゲットグループペア（テストトラフィック分離可能）
  dynamic "target_group_pair_info" {
    for_each = var.use_target_group_pair_info && length(var.alb_listener_arns) > 0 ? [1] : []
    content {
      prod_traffic_route {
        listener_arns = var.alb_listener_arns
      }

      dynamic "test_traffic_route" {
        for_each = length(var.blue_green_test_traffic_route_listener_arns) > 0 ? [1] : []
        content {
          listener_arns = var.blue_green_test_traffic_route_listener_arns
        }
      }

      target_group { name = var.alb_target_group_name }
      target_group { name = var.alb_target_group_name }
    }
  }

  # シンプル設定：単一ターゲットグループ
  dynamic "target_group_info" {
    for_each = !var.use_target_group_pair_info ? [1] : []
    content {
      name = var.alb_target_group_name
    }
  }
}
```

#### SNS トリガー設定
```hcl
dynamic "trigger_configuration" {
  for_each = var.enable_deployment_triggers && var.deployment_trigger_sns_topic_arn != "" ? [1] : []
  content {
    trigger_events     = ["DeploymentStart", "DeploymentSuccess", "DeploymentFailure", "DeploymentStop"]
    trigger_name       = "${local.codedeploy_group_name}-trigger"
    trigger_target_arn = var.deployment_trigger_sns_topic_arn
  }
}
```

#### CloudWatch アラーム監視
```hcl
dynamic "alarm_configuration" {
  for_each = var.enable_alarm_configuration && length(var.alarm_names) > 0 ? [1] : []
  content {
    alarms                     = var.alarm_names
    enabled                    = true
    ignore_poll_alarm_failure  = var.ignore_poll_alarm_failure
  }
}
```

### 3. 出力（outputs.tf）の拡張

```hcl
output "codedeploy_deployment_group_arn" {
  description = "ARN of the CodeDeploy deployment group"
  value       = try(aws_codedeploy_deployment_group.deployment_group[0].arn, "")
}

output "codedeploy_deployment_group_id" {
  description = "ID of the CodeDeploy deployment group"
  value       = try(aws_codedeploy_deployment_group.deployment_group[0].deployment_group_id, "")
}
```

## 使用例

### シンプル設定（既存のデフォルト動作）
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... 既存の設定 ...
  
  # CodeDeploy Deployment Group のデフォルト設定を使用
  # - Blue/Green デプロイメント
  # - トラフィックコントロール有効
  # - シンプルなターゲットグループ設定
}
```

### 高度な Blue/Green 設定
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... 既存の設定 ...
  
  # ターゲットグループペア設定を有効化
  use_target_group_pair_info = true
  alb_listener_arns          = [aws_lb_listener.prod.arn]
  blue_green_test_traffic_route_listener_arns = [aws_lb_listener.test.arn]
  
  # Blue インスタンスをすぐに終了
  codedeploy_termination_action             = "TERMINATE"
  codedeploy_termination_wait_time_in_minutes = 5
}
```

### SNS 通知有効化
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... 既存の設定 ...
  
  # デプロイメント通知を有効化
  enable_deployment_triggers      = true
  deployment_trigger_sns_topic_arn = aws_sns_topic.deployment_notifications.arn
}
```

### CloudWatch アラーム監視
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... 既存の設定 ...
  
  # アラーム監視を有効化
  enable_alarm_configuration = true
  alarm_names               = ["cpu-utilization-high", "error-rate-high"]
  ignore_poll_alarm_failure = false  # アラーム取得失敗時はデプロイ停止
}
```

## 主な機能

### 1. **Blue/Green デプロイメント制御**
- `CONTINUE_DEPLOYMENT` : Green インスタンスへのトラフィック切り替えをすぐに開始
- `STOP_DEPLOYMENT` : 手動でトラフィックを切り替えるまで待機

### 2. **トラフィック分離**
- `target_group_pair_info` を使用してテストトラフィックを分離
- 本番トラフィックの影響を受けずにデプロイ検証が可能

### 3. **自動ロールバック**
- デプロイメント失敗やアラーム条件を満たした場合に自動的にロールバック

### 4. **通知と監視**
- SNS トピックを通じた通知
- CloudWatch アラームによるメトリクス監視

## 後方互換性

すべての新しい変数はデフォルト値を持つため、既存の設定に影響を与えません。
新しい機能を使用する場合のみ、変数を指定してください。

## 参考資料

- [AWS Terraform Registry - aws_codedeploy_deployment_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group)
- [AWS CodeDeploy ドキュメント](https://docs.aws.amazon.com/codedeploy/)
