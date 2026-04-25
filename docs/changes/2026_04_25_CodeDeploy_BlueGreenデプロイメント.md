# CodeDeploy Blue/Green デプロイメント設定

## 概要

ECS サービスの Blue/Green デプロイメントに対応しました。ゼロダウンタイムでアプリケーションを更新するための構成です。

## 変更内容

### 1. ALB ターゲットグループの追加 (terraform/modules/network/alb/main.tf)

NextJS と Go Server の両方に対して、Blue/Green 用の 2 つのターゲットグループを作成しました。

```hcl
# NextJS
target_groups = {
  nextjs-blue = { ... }
  nextjs-green = { ... }
}

# Go Server  
target_groups = {
  go-server-blue = { ... }
  go-server-green = { ... }
}
```

### 2. ECS サービスから load_balancers を削除 (terraform/modules/compute/ecs/main.tf)

CodeDeploy が Blue/Green デプロイメント時にターゲットグループを管理するため、Terraform の `load_balancers` 設定を削除しました。
- ECS Service に `deployment_controller.type = "CODE_DEPLOY"` が設定されている場合、ロードバランサーの変更は CodeDeploy が管理します。

### 3. CodeDeploy Deployment Group の設定 (terraform/modules/cicd/main.tf)

#### NextJS Deployment Group
- `deployment_type = "BLUE_GREEN"`
- `deployment_option = "WITH_TRAFFIC_CONTROL"` (ALB でトラフィック制御)
- `blue_green_deployment_config` で以下を設定:
  - `deployment_ready_option`: `CONTINUE_DEPLOYMENT` で新しいインスタンスに即座にトラフィック転送
  - `terminate_blue_instances_on_deployment_success`: デプロイ成功後、古いインスタンスを `TERMINATE`

#### Go Server Deployment Group
- NextJS と同じ設定で Blue/Green デプロイメントに対応

### 4. load_balancer_info の設定

`target_group_pair_info` を使用して Blue/Green ターゲットグループペアを指定:

```hcl
load_balancer_info {
  target_group_pair_info {
    prod_traffic_route {
      listener_arns = [var.alb_listener_arn]
    }

    target_group {
      name = "${var.project_name}-nextjs-blue-${var.environment}"
    }

    target_group {
      name = "${var.project_name}-nextjs-green-${var.environment}"
    }
  }
}
```

### 5. 新しい変数の追加 (terraform/modules/cicd/variables.tf)

```hcl
variable "alb_listener_arn" {
  description = "ALB listener ARN for Blue/Green deployment configuration"
  type        = string
  default     = ""
}
```

## Blue/Green デプロイメント フロー

```
1. GitHub に Code Push
   ↓
2. Source Stage (GitHub)
   ↓
3. Build Stage (Docker イメージビルド & ECR Push)
   ↓
4. Scan Stage (セキュリティスキャン)
   ↓
5. [Approval Stage] (本番環境のみ)
   ↓
6. DeployNextJS Stage (CodeDeploy)
   - 新しいタスク定義を Green ターゲットグループで起動
   - ヘルスチェック成功後、ALB がトラフィックを Blue → Green に転送
   - Blue インスタンスを終了
   ↓
7. DeployGoServer Stage (CodeDeploy)
   - 同様に Blue/Green デプロイメント実行
```

## 主な特徴

✅ **ゼロダウンタイム** - デプロイ中もアプリケーション継続稼働  
✅ **自動ロールバック** - `DEPLOYMENT_FAILURE` で自動ロールバック  
✅ **トラフィック制御** - ALB でスムーズなトラフィック転送  
✅ **デプロイ速度** - `CONTINUE_DEPLOYMENT` で迅速な切り替え  

## 重要な注意事項

### CodeDeploy の制約
- ECS Service に `deployment_controller.type = "CODE_DEPLOY"` が設定されている場合、Terraform から `load_balancers` の更新はできません。
- ロードバランサーの設定は CodeDeploy デプロイメント時に実施されます。
- appspec.yaml で ターゲットグループペア情報を指定する必要があります。

### ターゲットグループ管理
- Blue ターゲットグループ: 初期デプロイ時のトラフィック受信
- Green ターゲットグループ: デプロイ後のトラフィック受信
- CodeDeploy が自動的にトラフィックを Blue → Green に切り替えます

## 設定が必要な項目

以下の変数を環境に応じて設定してください:

```hcl
# terraform/environments/dev.tfvars など

alb_listener_arn = "arn:aws:elasticloadbalancing:..."  # ALB リスナーの ARN
```

## 関連ファイル

- `terraform/modules/network/alb/main.tf` - ターゲットグループ定義
- `terraform/modules/cicd/main.tf` - CodeDeploy Deployment Group
- `terraform/modules/cicd/variables.tf` - 変数定義
- `terraform/modules/compute/ecs/main.tf` - ECS Service（load_balancers 削除）
- `appspec.yaml` - CodeDeploy アーティファクト定義（ECS 用）

## 動作確認

AWS CodePipeline コンソールでデプロイの進行状況を確認できます:

```
AWS Console > CodePipeline > [pipeline-name]
```

各ステージのログは CloudWatch Logs で確認:

```
/aws/codebuild/[project-name]
```

## トラブルシューティング

### "Unable to update load balancers on services with a CODE_DEPLOY deployment controller" エラー
- 原因: Terraform が load_balancers を更新しようとしている
- 解決: ECS Service から `load_balancer` ブロックを削除してください
- CodeDeploy がデプロイ時に自動管理します
