# CodeDeploy Deployment Group - 複数サービス対応（NextJS & Go Server 分離）

## 概要
単一の CodeDeploy Deployment Group で NextJS と Go Server の両方をデプロイしていた構成を、サービスごとに分離して独立したデプロイメント管理を実現しました。

## 変更内容

### 1. 設計思想
**問題点（変更前）:**
- NextJS と Go Server が同一の CodeDeploy Deployment Group でデプロイされていた
- 一方のサービスの更新が他方に影響を受ける可能性
- リリースサイクルが異なる場合に対応できない
- デプロイメント失敗時の影響範囲が大きい

**解決策（変更後）:**
- 各サービスに専用の Deployment Group を作成
- 独立したデプロイメント制御が可能
- 順序的デプロイメント（NextJS → Go Server）で依存関係を管理

### 2. variables.tf の更新

#### 新規追加変数
```hcl
# NextJS Service Configuration
variable "ecs_nextjs_cluster_name" {
  description = "ECS cluster name for Next.js service"
  type        = string
  default     = ""
}

variable "ecs_nextjs_service_name" {
  description = "ECS service name for Next.js service"
  type        = string
  default     = ""
}

# Go Server Service Configuration
variable "ecs_go_cluster_name" {
  description = "ECS cluster name for Go Server service"
  type        = string
  default     = ""
}

variable "ecs_go_service_name" {
  description = "ECS service name for Go Server service"
  type        = string
  default     = ""
}
```

#### 既存変数の変更
```hcl
variable "ecs_cluster_name" {
  # 後方互換性のためデフォルト値を ""に変更
  default = ""
}

variable "ecs_service_name" {
  # 後方互換性のためデフォルト値を ""に変更
  default = ""
}
```

### 3. main.tf の更新

#### 新しい Deployment Group リソース

**NextJS 用:**
```hcl
resource "aws_codedeploy_deployment_group" "nextjs_deployment_group" {
  count                  = var.ecs_nextjs_cluster_name != "" && var.ecs_nextjs_service_name != "" ? 1 : 0
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${local.codedeploy_group_name}-nextjs"
  # ... 設定詳細
  
  ecs_service {
    cluster_name = var.ecs_nextjs_cluster_name
    service_name = var.ecs_nextjs_service_name
  }
}
```

**Go Server 用:**
```hcl
resource "aws_codedeploy_deployment_group" "go_deployment_group" {
  count                  = var.ecs_go_cluster_name != "" && var.ecs_go_service_name != "" ? 1 : 0
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${local.codedeploy_group_name}-go"
  # ... 設定詳細
  
  ecs_service {
    cluster_name = var.ecs_go_cluster_name
    service_name = var.ecs_go_service_name
  }
}
```

#### CodePipeline Deploy ステージの分割

**デプロイメント実行順序:**
1. **DeployNextJS ステージ** (run_order = 1)
   - NextJS サービスをデプロイ
   
2. **DeployGoServer ステージ** (run_order = 2)
   - Go Server サービスをデプロイ
   - NextJS のデプロイが完了してから開始

```hcl
# Deploy Stage 1 - Next.js Deployment
dynamic "stage" {
  for_each = var.ecs_nextjs_cluster_name != "" && var.ecs_nextjs_service_name != "" ? [1] : []
  content {
    name = "DeployNextJS"
    action {
      run_order = 1
      # ...
    }
  }
}

# Deploy Stage 2 - Go Server Deployment
dynamic "stage" {
  for_each = var.ecs_go_cluster_name != "" && var.ecs_go_service_name != "" ? [1] : []
  content {
    name = "DeployGoServer"
    action {
      run_order = 2
      # ...
    }
  }
}
```

### 4. outputs.tf の更新

#### 新規出力
```hcl
# NextJS Deployment Group Outputs
output "codedeploy_nextjs_deployment_group_name" { }
output "codedeploy_nextjs_deployment_group_arn" { }
output "codedeploy_nextjs_deployment_group_id" { }

# Go Server Deployment Group Outputs
output "codedeploy_go_deployment_group_name" { }
output "codedeploy_go_deployment_group_arn" { }
output "codedeploy_go_deployment_group_id" { }
```

### 5. 後方互換性の維持
既存の `ecs_cluster_name` と `ecs_service_name` を使用する構成も引き続きサポートしています。
新しい変数を指定しない場合は、従来の単一 Deployment Group が作成されます。

## 使用方法

### パターン A: 新しい設定（推奨）
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... その他の設定 ...
  
  # NextJS サービス設定
  ecs_nextjs_cluster_name  = aws_ecs_cluster.main.name
  ecs_nextjs_service_name  = aws_ecs_service.nextjs.name
  
  # Go Server サービス設定
  ecs_go_cluster_name      = aws_ecs_cluster.main.name
  ecs_go_service_name      = aws_ecs_service.go_server.name
}
```

### パターン B: 従来の設定（後方互換性）
```hcl
module "cicd" {
  source = "./terraform/modules/cicd"
  
  # ... その他の設定 ...
  
  # 従来の単一サービス設定
  ecs_cluster_name  = aws_ecs_cluster.main.name
  ecs_service_name  = aws_ecs_service.legacy.name
}
```

## メリット

### 1. **独立したデプロイメント管理**
- NextJS と Go Server を独立してデプロイ可能
- 一方の障害が他方に影響を与えない

### 2. **柔軟なリリース戦略**
- 異なるリリース頻度に対応
- サービスごとにロールバック戦略を適用

### 3. **明確なデプロイメント順序**
- NextJS → Go Server の順で実行
- 依存関係を明示的に管理

### 4. **スケーラビリティ**
- 新しいマイクロサービスを追加しやすい
- 各サービスのリソース管理を独立化

## 注意点

### 1. **CodePipeline の動作**
- DeployNextJS ステージが完了するまで、DeployGoServer ステージは開始されません
- デプロイメント失敗時は、失敗したサービスのみロールバックされます

### 2. **appspec.yaml の確認**
- NextJS と Go Server の各 appspec.yaml が正しく設定されていることを確認してください
- サービス識別子（例：`nextjs`、`go-server`）が一致していることを確認

### 3. **マイグレーション**
既存の構成から移行する場合：
1. 新しい変数を terraform.tfvars に追加
2. `terraform plan` で変更内容を確認
3. `terraform apply` で適用

## トラブルシューティング

### Q: DeployGoServer ステージが作成されない
A: `ecs_go_cluster_name` と `ecs_go_service_name` が両方空になっていないか確認してください。両方指定が必要です。

### Q: デプロイメント順序が変わった
A: CodePipeline の設定では、各ステージの `run_order` によって実行順序が決定されます。デフォルトは NextJS が 1、Go Server が 2 です。

## 関連ドキュメント
- [AWS CodeDeploy Deployment Group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group)
- [AWS CodePipeline](https://docs.aws.amazon.com/codepipeline/)
