# ECSタスク定義修正とCODE_DEPLOY対応

## 概要

ターゲットグループにタスクが登録されない問題を診断し、2つの根本原因を特定・修正しました。

1. **タスク定義内の CPU/メモリが未指定** → タスク起動失敗
2. **Terraform が CODE_DEPLOY 管理下のサービス更新を試みる** → エラー発生

## 問題の診断

### 症状

```
desiredCount: 2
runningCount: 0  ❌ タスクが起動していない
pendingCount: 0  ❌ 待機中のタスクもない
```

AWS ECS サービスの状態確認コマンド：
```bash
aws ecs describe-services \
  --cluster ecs-sample-cluster-dev \
  --services ecs-sample-nextjs-service \
  --region ap-northeast-1
```

### 根本原因の特定

#### 原因1：タスク定義の不完全な設定

AWS ECS タスク定義の確認：
```bash
aws ecs describe-task-definition \
  --task-definition ecs-sample-nextjs:5 \
  --region ap-northeast-1
```

**発見された問題：**
```json
{
  "cpu": 0,  // ❌ Fargateでは無効（256, 512, 1024, 2048, 4096 が有効値）
  "memory": ...,
  "containerDefinitions": [
    {
      "cpu": 0,  // ❌ コンテナレベルでも指定されていない
      "environment": [
        {
          "name": "API_BASE_URL",
          "value": "http://"  // ❌ ホスト名が空
        }
      ]
    }
  ]
}
```

#### 原因2：Terraform 構成の矛盾

ECS サービスが `deployment_controller { type = "CODE_DEPLOY" }` で定義されていたが、Terraform が直接サービスを更新しようとしていました。

**エラーメッセージ：**
```
Unable to update task definition on services with a CODE_DEPLOY 
deployment controller. Use AWS CodeDeploy to trigger a new deployment.
```

---

## 実装した修正

### 修正1：コンテナ定義に CPU/メモリを明示的に追加

**ファイル：** `terraform/modules/compute/ecs/main.tf`

#### Next.js タスク定義（行245-264）

```hcl
resource "aws_ecs_task_definition" "nextjs" {
  ...
  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-nextjs"
      image     = "..."
      essential = true
      cpu       = var.nextjs_task_cpu          # 👈 追加
      memory    = var.nextjs_task_memory       # 👈 追加
      portMappings = [...]
      logConfiguration = {...}
      environment = concat(
        var.nextjs_environment_variables,
        var.private_alb_dns_name != "" ? [
          {
            name  = "NEXT_PUBLIC_API_BASE_URL"
            value = "http://${var.private_alb_dns_name}"  # 環境変数が正しく生成される
          }
        ] : []
      )
      secrets = var.nextjs_secrets
    }
  ])
}
```

#### Go Server タスク定義（行277-305）

同様の修正をGoサーバータスク定義にも適用

#### JSON 出力ファイルの環境変数追加

`nextjs-taskdef.json` にも環境変数を含める修正：

```hcl
resource "local_file" "nextjs_taskdef_json" {
  content = jsonencode({
    ...
    containerDefinitions = [
      {
        ...
        environment = concat(
          var.nextjs_environment_variables,
          var.private_alb_dns_name != "" ? [
            {
              name  = "NEXT_PUBLIC_API_BASE_URL"
              value = "http://${var.private_alb_dns_name}"
            }
          ] : []
        )
      }
    ]
  })
}
```

### 修正2：CODE_DEPLOY 管理下でのライフサイクル設定

**ファイル：** `terraform/modules/compute/ecs/main.tf`

#### Next.js サービス（行426-437）

```hcl
resource "aws_ecs_service" "nextjs" {
  ...
  deployment_controller {
    type = "CODE_DEPLOY"  # CodeDeployがデプロイを管理
  }

  # CODE_DEPLOYで管理される属性はTerraformで直接更新しない
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
```

#### Go Server サービス（line 455-466）

同様にライフサイクル設定を追加

---

## 修正内容の詳細

### 1. CPU/メモリ設定が重要な理由

Fargate では以下の CPU/メモリ組み合わせが有効です：

| CPU | メモリ（MB） |
|-----|-----------|
| 256 | 512-2048 (256MB単位) |
| 512 | 1024-4096 (1GB単位) |
| 1024 | 2048-8192 (1GB単位) |
| 2048 | 4096-16384 (1GB単位) |
| 4096 | 8192-30720 (1GB単位) |

`cpu = 0` はいずれの有効値にも該当しないため、タスク起動時にエラーが発生します。

### 2. CODE_DEPLOY との統合

CODE_DEPLOY デプロイメントコントローラーを使用する場合：

```
Terraform（Infrastructure as Code）
    ↓
初回デプロイ：サービス作成、基本設定
    ↓
以降のデプロイ：Terraform は ignore_changes で更新を無視
    ↓
CodeDeploy（CI/CD パイプライン）
    ↓
AppSpec ファイルで新タスク定義を指定
    ↓
Blue/Green デプロイメント実行
```

**重要：**
- Terraform が `task_definition` を更新しようとすると、CODE_DEPLOY 管理下のサービスと競合します
- `ignore_changes = [task_definition, desired_count]` で Terraform の直接更新を回避
- デプロイメント（タスク更新）は CodeDeploy で管理されるようになります

### 3. 環境変数の設定

```hcl
private_alb_dns_name = ""  # 初期値が空

# Terraform 実行時に以下の値に置き換わる
private_alb_dns_name = "ecs-sample-private-alb-dev-1234567890.ap-northeast-1.elb.amazonaws.com"

# するとタスク定義内では：
{
  name: "NEXT_PUBLIC_API_BASE_URL",
  value: "http://ecs-sample-private-alb-dev-1234567890.ap-northeast-1.elb.amazonaws.com"
}
```

---

## 検証方法

### Step 1: 修正の反映

```bash
cd terraform
terraform plan
terraform apply
```

### Step 2: タスク起動確認

```bash
# タスクが RUNNING 状態になることを確認
aws ecs describe-services \
  --cluster ecs-sample-cluster-dev \
  --services ecs-sample-nextjs-service \
  --region ap-northeast-1

# 期待される出力：
# "runningCount": 2
# "desiredCount": 2
```

### Step 3: ターゲットグループ確認

```bash
# ターゲットが登録されていることを確認
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-1:...
```

**期待される出力：**
```json
{
  "Targets": [
    {
      "Id": "10.0.10.x",
      "Port": 3000,
      "HealthCheckState": "healthy"
    },
    {
      "Id": "10.0.11.x",
      "Port": 3000,
      "HealthCheckState": "healthy"
    }
  ]
}
```

### Step 4: CloudWatch ログ確認

```bash
aws logs tail /ecs/ecs-sample-nextjs-dev --follow
```

タスクが正常に起動できるようになります。

---

## 影響範囲

### 直接的な影響

- **ECS タスク定義（Next.js/Go Server）**
  - コンテナレベルで CPU/メモリが明示的に設定される
  - JSON 出力ファイルに環境変数が含まれるようになる

- **ECS サービス（Next.js/Go Server）**
  - `lifecycle { ignore_changes }` で Terraform 更新競合を回避
  - CodeDeploy がデプロイメント全体を管理

### 間接的な影響

- **CodeDeploy デプロイメント**
  - AppSpec ファイルで指定した新タスク定義で確実にデプロイされるようになる
  - Blue/Green 切り替えが正常に動作

- **ALB ターゲットグループ**
  - タスクが自動的に登録・削除されるようになる
  - ヘルスチェックが正常に機能

---

## 注意事項

### Terraform 管理方針の変更

以前：Terraform がすべての ECS リソースの更新を管理
```hcl
# ❌ 従来（CODE_DEPLOY 非対応）
resource "aws_ecs_service" "nextjs" {
  task_definition = aws_ecs_task_definition.nextjs.arn  # Terraform が常に更新
}
```

新しい方針：初期構築は Terraform、デプロイメント管理は CodeDeploy
```hcl
# ✅ 新しい（CODE_DEPLOY 対応）
resource "aws_ecs_service" "nextjs" {
  task_definition = aws_ecs_task_definition.nextjs.arn
  
  lifecycle {
    ignore_changes = [task_definition, desired_count]  # CodeDeploy 管理に委譲
  }
}
```

### 今後のデプロイメント手順

```
Git push → CodePipeline → CodeBuild → CodeDeploy → ECS タスク更新
                                   ↑
                          (Terraform は関与しない)
```

---

## 参考資料

- [AWS ECS Fargate CPU/Memory](https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task-cpu-memory-error.html)
- [AWS CodeDeploy で ECS デプロイ](https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/deployments-steps-ecs.html)
- [Terraform aws_ecs_service lifecycle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#lifecycle)
