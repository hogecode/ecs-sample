# Terraformエラー修正: CodeDeploy - LoadBalancerInfo 必須エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating CodeDeploy Deployment Group (ecs-sample-dev-deployment-group): 
operation error CodeDeploy: CreateDeploymentGroup, https response error StatusCode: 400, 
RequestID: a9fb83f5-6779-4a3a-bc91-d3d9153b9706, InvalidLoadBalancerInfoException: 
For ECS deployment group, loadBalancerInfo must be specified
```

## 問題の原因
AWS CodeDeploy の ECS Deployment Group では、ALB を使用する場合は必ず load_balancer_info を指定する必要があります。ALB が設定されていない場合、このパラメータを指定すると AWS API エラーが発生します。

## 実装した解決策
Deployment Group と CodePipeline の Deploy stage を count で条件付き化し、`alb_target_group_arn` が空でない場合のみ作成するようにしました。

### 修正内容
**ファイル:** `terraform/modules/cicd/main.tf`

1. **CodeDeploy Deployment Group（修正前）:**
```hcl
resource "aws_codedeploy_deployment_group" "deployment_group" {
  # loadBalancerInfo が無いため AWS API エラー
}
```

2. **CodeDeploy Deployment Group（修正後）:**
```hcl
resource "aws_codedeploy_deployment_group" "deployment_group" {
  count                  = var.alb_target_group_arn != "" ? 1 : 0
  # alb_target_group_arn が空でない場合のみ作成
  
  load_balancer_info {
    target_group_info {
      name = var.alb_target_group_name
    }
  }
}
```

3. **CodePipeline Deploy stage（修正前）:**
```hcl
stage {
  name = "Deploy"
  action {
    # deployment_group が存在しない場合、参照エラー
  }
}
```

4. **CodePipeline Deploy stage（修正後）:**
```hcl
dynamic "stage" {
  for_each = var.alb_target_group_arn != "" ? [1] : []
  content {
    name = "Deploy"
    action {
      # deployment_group[0] でインデックス付きアクセス
      DeploymentGroupName = aws_codedeploy_deployment_group.deployment_group[0].deployment_group_name
    }
  }
}
```

## 変数設定
**ファイル:** `terraform/modules/cicd/variables.tf`

```hcl
variable "alb_target_group_arn" {
  description = "ALB target group ARN for load balancer configuration"
  type        = string
  default     = ""  # 空の場合、CodeDeploy/Deploy stage は作成されない
}

variable "alb_target_group_name" {
  description = "ALB target group name for CodeDeploy configuration"
  type        = string
  default     = ""
}
```

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 設定例

### ALB を使用する場合
```hcl
# terraform/environments/dev.tfvars
alb_target_group_arn  = "arn:aws:elasticloadbalancing:ap-northeast-1:ACCOUNT_ID:targetgroup/ecs-sample-dev/xxxxx"
alb_target_group_name = "ecs-sample-dev"
```

### ALB を使用しない場合
```hcl
# terraform/environments/dev.tfvars
alb_target_group_arn  = ""  # 空のままにする
alb_target_group_name = ""
```

## 注意点
- alb_target_group_arn が空の場合、CodeDeploy Deployment Group は作成されません
- Deploy stage も作成されません
- ECS Service のデプロイは別途手動で実施するか、別のデプロイ方法を使用してください
- 本番環境では ALB による自動デプロイを推奨します
