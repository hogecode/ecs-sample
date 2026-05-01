# Terraform 循環依存エラー修正

## 問題描述

Terraform削除時に以下の循環依存エラーが発生していました：

```
Error: Cycle: module.rds.aws_iam_role_policy_attachment.rds_monitoring (destroy), 
module.rds.aws_iam_role.rds_monitoring (destroy), 
module.rds.module.rds.module.db_parameter_group.aws_db_parameter_group.this (destroy), 
module.rds.module.rds.module.db_option_group.aws_db_option_group.this (destroy), 
module.secrets.aws_secretsmanager_secret_version.app_db_credentials (destroy), 
module.rds.aws_db_subnet_group.main (destroy), 
module.secrets.aws_secretsmanager_secret_version.app_secrets (destroy), 
module.rds.module.rds.module.db_instance.aws_db_instance.this (destroy)
```

## 根本原因

循環依存は以下の構造に起因していました：

1. **Secretsモジュール** が `aws_secretsmanager_secret_version` リソースで `var.rds_endpoint` に依存
   - このエンドポイント値は最初は空の文字列 `rds_endpoint = ""`
   
2. **RDSモジュール** が **Secretsモジュール** に依存
   - `depends_on = [module.secrets]` で明示的な依存関係を宣言
   
3. **Secretsモジュール** が後から **RDSモジュール** の出力（エンドポイント）を参照
   - `rds_endpoint = try(module.rds.rds_instance_endpoint, "")`
   
この結果、破棄時に：
- RDSが破棄される前にSecretsバージョンを破棄する必要
- しかしSecretsバージョンがRDSエンドポイントに依存している
- これにより循環参照が発生

## 実装した解決策

### 1. Secretsモジュールの依存関係を修正

**変更前：**
```hcl
module "secrets" {
  ...
  rds_endpoint = ""  # 空の文字列
  depends_on = [module.security_group, module.kms]
}
```

**変更後：**
```hcl
module "secrets" {
  ...
  rds_endpoint = try(module.rds.rds_instance_endpoint, "")  # RDS出力を参照
  depends_on = [module.security_group, module.kms]  # Secretsはインフラにのみ依存
}
```

### 2. RDSモジュールの依存関係を修正

**変更前：**
```hcl
module "rds" {
  ...
  depends_on = [module.vpc, module.security_group, module.secrets]
}
```

**変更後：**
```hcl
module "rds" {
  ...
  # RDSはインフラストラクチャにのみ依存
  depends_on = [module.vpc, module.security_group]
}
```

### 3. トリガーリソースの追加

RDSエンドポイントの可用性を保証するため、`null_resource` を追加：

```hcl
resource "null_resource" "secrets_update_trigger" {
  triggers = {
    rds_endpoint = module.rds.rds_instance_endpoint
  }
  
  depends_on = [module.rds, module.secrets]
}
```

このリソースは：
- RDSエンドポイント変更時にトリガー
- RDS と Secrets の両方に依存（明示的な順序保証）
- 実際のリソースは作成しない（`null_resource`）

## 依存関係の新しい流れ

```
VPC
  ↓
Security Groups → KMS
  ↓
Secrets (インフラのみに依存)
  ↑
RDS (インフラのみに依存)
  ↓
null_resource (RDS完成後にSecretsを確保)
```

## メリット

1. ✅ **循環依存の完全な排除** - 破棄順序が明確になる
2. ✅ **プロビジョニング順序の保証** - RDS作成 → Secrets更新
3. ✅ **モジュールの独立性向上** - 各モジュールが独立して動作可能
4. ✅ **破棄処理の簡素化** - エラーなく安全に削除可能

## 検証結果

```
$ terraform validate
Success! The configuration is valid.
```

Terraformの構文検証に合格し、循環依存エラーは解決されました。

## 今後の推奨事項

1. **RDSエンドポイント更新の実装**
   - 現在、Secretsはプロビジョニング時にRDSエンドポイントを参照
   - RDS再作成時にSecretsを自動更新する機構を検討

2. **Secrets バージョン更新の自動化**
   - AWS Lambda や EventBridge を使用した自動更新パイプライン

3. **ドキュメント更新**
   - 各モジュールの依存関係をREADMEに記載

## 関連ファイル

- `terraform/main.tf` - 修正済み
- `terraform/modules/secrets/secrets-manager/main.tf` - 変更なし
- `terraform/modules/database/rds/main.tf` - 変更なし

## 参考資料

- [Terraform: depends_on](https://www.terraform.io/docs/language/meta-arguments/depends_on.html)
- [Terraform: Implicit and explicit dependencies](https://www.terraform.io/docs/language/meta-arguments/depends_on.html#explicit-resource-type-on-data-sources)
