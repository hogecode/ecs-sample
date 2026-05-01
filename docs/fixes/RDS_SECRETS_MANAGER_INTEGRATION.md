# RDS と Secrets Manager の統合アーキテクチャ

## 概要

このドキュメントでは、AWS RDS と AWS Secrets Manager を統合したシンプルで安全なシークレット管理アーキテクチャについて説明します。

## 問題背景

以前の実装では、Terraform が手動でパスワードを生成し、Secrets Manager に保存していました。しかし、RDSモジュールの `manage_master_user_password` デフォルト値が `true` のため、AWS が自動的に別のシークレット（`rds!db-...`）を生成してしまい、**パスワード同期エラー** が発生していました。

```
問題のパターン（修正前）:
┌─────────────────────┐
│ Terraform Secrets   │
│ (manual password)    │
└─────────────────────┘
           ↓
        ≠ パスワード値が異なる
           ↓
┌─────────────────────┐
│ AWS RDS             │
│ (auto password)      │
└─────────────────────┘
```

## 新しいアーキテクチャ

### 設計思想

**AWS RDS が自動管理する Secrets Manager シークレット を活用する**

```
RDS モジュール
  ↓
  manage_master_user_password = true（AWS自動管理）
  ↓
AWS Secrets Manager
  ├─ RDS マスターユーザーシークレット（ARN出力）
  │  └─ username: admin
  │  └─ password: AWS自動生成・管理
  │
  └─ ECS が ARN経由で参照
```

### パスワード管理の全体像

```
┌──────────────────────────────────────────────────────────────────┐
│                    Secrets Manager                                │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. RDS Master Secret (AWS Managed)                              │
│     ├─ ARN: module.rds.db_instance_master_user_secret_arn        │
│     ├─ Username: admin (RDSマスターユーザー)                      │
│     ├─ Password: AWS自動生成                                      │
│     └─ 用途: RDS認証（管理者用）                                  │
│                                                                   │
│  2. App DB Credentials (Terraform Managed via Secrets Module)    │
│     ├─ ARN: module.secrets.app_db_credentials_arn                │
│     ├─ Username: appuser (アプリケーション用ユーザー)            │
│     ├─ Password: Terraform生成                                    │
│     └─ 用途: ECS Go Serverが使用                                 │
│                                                                   │
│  3. App Secrets (Terraform Managed via Secrets Module)           │
│     ├─ ARN: module.secrets.app_secrets_arn                       │
│     ├─ Content: API_KEY, DB_PASSWORD, etc.                       │
│     └─ 用途: ECS Next.js/Go Serverが使用                         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## 実装詳細

### 1. RDS モジュール（`terraform/modules/database/rds/main.tf`）

```hcl
module "rds" {
  source = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  # ... 既存設定 ...

  # ✅ AWS Secrets Manager で自動管理を有効化
  manage_master_user_password = true

  # username/password は設定可能（初期化用）
  # ただし、以降の管理は AWS が行う
  username = var.rds_username
  password = var.rds_password
}
```

**重要:** `manage_master_user_password = true` の場合、以降のパスワード変更は AWS Secrets Manager Rotation 機能で行われます。

### 2. RDS モジュール出力（`terraform/modules/database/rds/outputs.tf`）

```hcl
output "db_instance_master_user_secret_arn" {
  description = "ARN of the RDS master user secret (managed by AWS Secrets Manager)"
  value       = module.rds.db_instance_master_user_secret_arn
  sensitive   = true
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint (connection string)"
  value       = module.rds.db_instance_endpoint
}
```

### 3. root モジュール（`terraform/main.tf`）

```hcl
module "ecs" {
  # ... 既存設定 ...

  # ✅ RDS マスターシークレット ARN を ECS に渡す
  rds_master_user_secret_arn = module.rds.db_instance_master_user_secret_arn

  depends_on = [module.vpc, module.security_group, module.alb, module.ecr, module.secrets, module.rds]
}
```

### 4. ECS モジュール変数（`terraform/modules/compute/ecs/variables.tf`）

```hcl
variable "rds_master_user_secret_arn" {
  description = "ARN of the RDS master user secret (managed by AWS Secrets Manager)"
  type        = string
  default     = ""
}
```

### 5. ECS タスク定義での使用（`terraform/modules/compute/ecs/main.tf`）

```hcl
# Go Server Task Definition
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": var.rds_master_user_secret_arn
  },
  {
    "name": "DB_HOST",
    "valueFrom": "${var.rds_master_user_secret_arn}:host"
  },
  {
    "name": "DB_PORT",
    "valueFrom": "${var.rds_master_user_secret_arn}:port"
  }
]
```

**注:** Secrets Manager のARNを直接参照することで、ECS が実行時に最新のシークレット値を自動的に取得します。

## メリット

| メリット | 説明 |
|---------|------|
| **パスワード同期** | AWS が自動管理するため、常に同期 ✅ |
| **セキュリティ** | 手動でパスワードを管理しないため安全 |
| **自動回転** | AWS Secrets Manager Rotation で定期的なパスワード更新可能 |
| **監査** | CloudTrail で全アクセス記録 |
| **IaC統合** | Terraform との統合もシンプル |
| **複雑性削減** | 手動パスワード生成コード不要 |

## 利用フロー

```
1. Terraform Apply
   └─ RDS 起動（manage_master_user_password = true）
       └─ AWS が自動で Secrets Manager に シークレット作成
           └─ ARN を出力

2. Terraform Output
   └─ module.rds.db_instance_master_user_secret_arn
       └─ arn:aws:secretsmanager:region:account:secret:rds!db-...

3. ECS Deployment
   └─ タスク定義の "valueFrom" に ARN を指定
       └─ コンテナ起動時に Secrets Manager から値を取得
           └─ 環境変数として注入

4. Application（Go Server）
   └─ 環境変数 DB_PASSWORD から値を読み取る
       └─ RDS に接続
```

## セキュリティベストプラクティス

### ✅ 実装済み

1. **KMS暗号化** - Secrets Manager が KMS で暗号化
2. **IAM制御** - ECS タスクロールで Secrets Manager アクセス許可
3. **CloudTrail監査** - Secrets 取得操作をログ記録
4. **敏感情報の保護** - Terraform state でも `sensitive = true`
5. **パスワード管理分離**
   - RDS マスター：AWS 自動管理
   - アプリケーション用：Terraform 管理

### 将来の改善

1. **自動パスワード回転** - Lambda + Secrets Manager Rotation
2. **複数リージョンレプリケーション** - マルチリージョン対応
3. **監視・アラート** - パスワード回転失敗時の通知

## ユーザー作成フロー

現在、RDS に `appuser` を自動作成していません。以下の方法を検討してください：

### オプション 1: Lambda 関数で自動作成（推奨）

```python
# Lambda 関数
def lambda_handler(event, context):
    secret = json.loads(get_secret(master_secret_arn))
    
    conn = mysql.connector.connect(
        host=secret['host'],
        user=secret['username'],
        password=secret['password']
    )
    
    cursor = conn.cursor()
    cursor.execute(f"CREATE USER 'appuser'@'%' IDENTIFIED BY '{app_password}'")
    cursor.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ecsdb.* TO 'appuser'@'%'")
    conn.commit()
```

### オプション 2: EC2 Bastion で手動実行

```bash
# SSM経由で Bastion に接続
aws ssm start-session --target i-xxxxx

# Bastion 上で実行
mysql -h rds-endpoint -u admin -p < init.sql
```

### オプション 3: Terraform Null Provider

```hcl
resource "null_resource" "create_app_user" {
  provisioner "local-exec" {
    command = "mysql -h ${module.rds.db_instance_endpoint} -u admin -p${module.secrets.rds_master_password} < init.sql"
  }
  
  depends_on = [module.rds]
}
```

## トラブルシューティング

### Q: "Task execution role is missing credentials"

**A:** ECS タスク実行ロールに `secretsmanager:GetSecretValue` 権限がない。

```hcl
# ECS タスク実行ロール ポリシーに追加
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:*:*:secret:rds!db-*"
}
```

### Q: "Secrets Manager パスワード値が表示されない"

**A:** `aws secretsmanager get-secret-value` でシークレットバージョンが複数ある場合、最新バージョンを指定。

```bash
aws secretsmanager get-secret-value \
  --secret-id 'arn:aws:secretsmanager:ap-northeast-1:xxx:secret:rds!db-xxx' \
  --version-stage AWSCURRENT \
  --query SecretString
```

### Q: "RDS に接続できない"

**A:** 複数の原因が考えられます：

1. **ユーザーが存在しない** - `admin` ユーザーで接続確認
2. **セキュリティグループ** - RDS SG がコンテナからの TCP 3306 アクセスを許可しているか確認
3. **ネットワーク** - プライベートサブネット、NAT Gateway 設定確認

## 関連ファイル

| ファイル | 説明 | 変更 |
|---------|------|------|
| `terraform/modules/database/rds/main.tf` | RDS モジュール | ✅ manage_master_user_password = true 追加 |
| `terraform/modules/database/rds/outputs.tf` | 出力値定義 | ✅ db_instance_master_user_secret_arn 追加 |
| `terraform/main.tf` | root モジュール | ✅ rds_master_user_secret_arn を ECS に渡す |
| `terraform/modules/compute/ecs/variables.tf` | ECS 変数 | ✅ rds_master_user_secret_arn を追加 |
| `terraform/modules/compute/ecs/main.tf` | ECS タスク定義 | 未実装（必要に応じて） |

## まとめ

このアーキテクチャにより：

- ✅ **パスワード同期の複雑さを排除**
- ✅ **AWS ネイティブ機能を活用**
- ✅ **セキュリティ向上**
- ✅ **運用負荷削減**

が実現されます。
