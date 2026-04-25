# Private ALB ドメイン名を Next.js 環境変数に統合

## 背景

Next.js コンテナが Go Server（Private ALB 経由）と通信する場合、Private ALB のドメイン名を動的に環境変数として設定する必要があります。この実装により、環境ごと（dev/staging/prod）に異なるドメイン名が自動的に設定されます。

## 問題の詳細

### 旧構造
Next.js が Go Server の API にアクセスする際、ALB のドメイン名をハードコードするか、手動で設定する必要がありました。

### 新しい構造
Terraform がインフラを構築する際に、Private ALB のドメイン名を自動的に Next.js コンテナの環境変数として注入します。

## 実装内容

### 1. ECS モジュール - 変数定義（`terraform/modules/compute/ecs/variables.tf`）

新しい入力変数を追加：

```hcl
# ========================================
# Internal Communication Configuration
# ========================================

variable "private_alb_dns_name" {
  description = "Private ALB DNS name for internal service communication"
  type        = string
  default     = ""
}
```

### 2. ECS モジュール - TaskDefinition 定義（`terraform/modules/compute/ecs/main.tf`）

Next.js コンテナの環境変数に Private ALB DNS を動的にマージ：

```hcl
environment = concat(
  var.nextjs_environment_variables,
  var.private_alb_dns_name != "" ? [
    {
      name  = "PRIVATE_ALB_DNS_NAME"
      value = var.private_alb_dns_name
    }
  ] : []
)
```

**メリット：**
- `var.nextjs_environment_variables` のカスタム値とマージ可能
- Private ALB DNS が空の場合は環境変数を追加しない（安全性）
- ECS モジュール内で完結し、`root main.tf` では追加の tfvars 設定不要

### 3. Root モジュール - ECS モジュール呼び出し（`terraform/main.tf`）

ECS モジュールに Private ALB DNS を渡す：

```hcl
module "ecs" {
  # ... 既存設定 ...

  # Internal Communication Configuration
  private_alb_dns_name = module.alb.private_alb_dns_name

  # NextJS Environment Variables (with dynamic ALB DNS reference)
  nextjs_environment_variables = local.nextjs_environment_variables_merged

  depends_on = [module.vpc, module.security_group, module.alb, module.ecr]
}
```

また、`local.nextjs_environment_variables_merged` を定義して、Next.js 標準の環境変数も設定：

```hcl
locals {
  nextjs_environment_variables_merged = concat(
    [
      {
        name  = "NEXT_PUBLIC_API_BASE_URL"
        value = "http://${module.alb.private_alb_dns_name}"
      },
      {
        name  = "API_BASE_URL"
        value = "http://${module.alb.private_alb_dns_name}"
      },
      {
        name  = "NODE_ENV"
        value = "production"
      }
    ],
    var.nextjs_environment_variables
  )
}
```

## 環境変数一覧

### Next.js コンテナに設定される環境変数

| 変数名 | 値 | 用途 |
|------|-----|------|
| `PRIVATE_ALB_DNS_NAME` | `internal-alb-xxxx.ap-northeast-1.elb.amazonaws.com` | Go Server との通信用ドメイン名 |
| `NEXT_PUBLIC_API_BASE_URL` | `http://{PRIVATE_ALB_DNS_NAME}` | クライアント向けAPI ベースURL |
| `API_BASE_URL` | `http://{PRIVATE_ALB_DNS_NAME}` | サーバー向けAPI ベースURL |
| `NODE_ENV` | `production` | Node.js 環境指定 |
| その他 | `var.nextjs_environment_variables` からのカスタム変数 | ユーザー定義 |

## Next.js での使用例

```typescript
// lib/api.ts
const PRIVATE_ALB_DNS_NAME = process.env.PRIVATE_ALB_DNS_NAME;
const GO_SERVER_URL = `http://${PRIVATE_ALB_DNS_NAME}:8080`;

export async function fetchUserData() {
  const response = await fetch(`${GO_SERVER_URL}/api/users`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  });
  return response.json();
}
```

## 生成される環境変数の例

### Dev 環境
```json
{
  "PRIVATE_ALB_DNS_NAME": "ecs-sample-private-alb-dev-xxxxxxxx.ap-northeast-1.elb.amazonaws.com",
  "NEXT_PUBLIC_API_BASE_URL": "http://ecs-sample-private-alb-dev-xxxxxxxx.ap-northeast-1.elb.amazonaws.com",
  "API_BASE_URL": "http://ecs-sample-private-alb-dev-xxxxxxxx.ap-northeast-1.elb.amazonaws.com",
  "NODE_ENV": "production"
}
```

### Prod 環境
```json
{
  "PRIVATE_ALB_DNS_NAME": "ecs-sample-private-alb-prod-yyyyyyyy.ap-northeast-1.elb.amazonaws.com",
  "NEXT_PUBLIC_API_BASE_URL": "http://ecs-sample-private-alb-prod-yyyyyyyy.ap-northeast-1.elb.amazonaws.com",
  "API_BASE_URL": "http://ecs-sample-private-alb-prod-yyyyyyyy.ap-northeast-1.elb.amazonaws.com",
  "NODE_ENV": "production"
}
```

## 効果

✅ Next.js が環境に応じた正しい Private ALB ドメイン名を自動取得  
✅ tfvars に環境変数を記述する手間が不要  
✅ ECS モジュール内で environment variables をマージ処理が完結  
✅ ユーザー定義のカスタム環境変数も共存可能  
✅ Terraform 検証済み（`terraform validate` 成功）  

## 関連ファイル

- `terraform/modules/compute/ecs/variables.tf`: ECS モジュール変数（`private_alb_dns_name` 追加）
- `terraform/modules/compute/ecs/main.tf`: ECS タスク定義（環境変数マージロジック）
- `terraform/main.tf`: ルートモジュール（ECS に ALB DNS を渡す）
- `terraform/modules/network/alb/outputs.tf`: ALB モジュール出力（`private_alb_dns_name` 参照）

## 参考資料

- [AWS ECS Task Definition - environment](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-taskdefinition.html)
- [Terraform - Null Resource Provider](https://registry.terraform.io/providers/hashicorp/null/latest/docs)
- [Application Load Balancer - DNS Names](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
