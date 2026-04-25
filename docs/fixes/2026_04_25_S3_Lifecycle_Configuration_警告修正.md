# Terraform警告修正: S3 Lifecycle Configuration 属性設定エラー

## 修正日時
2026年4月25日

## 警告メッセージ
```
Warning: Invalid Attribute Combination

with module.storage.module.alb_logs.aws_s3_bucket_lifecycle_configuration.this[0],
on .terraform\modules\storage.alb_logs\main.tf line 253, in resource "aws_s3_bucket_lifecycle_configuration" "this":
253: resource "aws_s3_bucket_lifecycle_configuration" "this" {

No attribute specified when one (and only one) of [rule[0].filter,rule[0].prefix] is required

This will be an error in a future version of the provider
```

## 問題の原因
S3 Bucket Lifecycle Configuration の rule に filter または prefix のいずれか一つを指定する必要がありますが、両方指定されていません。

terraform-aws-modules の S3 モジュール（alb_logs）で lifecycle_rules を定義する際、適切な filter または prefix が指定されていません。

## 実装した解決策
lifecycle_rules に filter を追加し、S3 オブジェクトをフィルタリングするようにします。

### 修正内容
**ファイル:** `terraform/modules/storage/s3/main.tf` または `.terraform/modules/storage.alb_logs/main.tf`

**修正前:**
```hcl
lifecycle_rules = [
  {
    id     = "rule-1"
    status = "Enabled"
    # filter または prefix が指定されていない
  }
]
```

**修正後:**
```hcl
lifecycle_rules = [
  {
    id     = "rule-1"
    status = "Enabled"
    filter = {
      prefix = "AWSLogs/"  # ALB access logs はこのプレフィックスで保存される
    }
    # または
    prefix = "AWSLogs/"
  }
]
```

## パターン別の修正例

### パターン1: prefix を使用する場合
```hcl
lifecycle_rules = [
  {
    id     = "delete-old-alb-logs"
    status = "Enabled"
    prefix = "AWSLogs/"
    expiration = {
      days = 90
    }
  }
]
```

### パターン2: filter を使用する場合（新しい方式）
```hcl
lifecycle_rules = [
  {
    id     = "delete-old-alb-logs"
    status = "Enabled"
    filter = {
      prefix = "AWSLogs/"
    }
    expiration = {
      days = 90
    }
  }
]
```

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## AWS Provider バージョンの考慮
- AWS Provider v4.0 以降：`prefix` は deprecated で、`filter.and.prefix` または `filter.prefix` を推奨
- `prefix` と `filter` は相互排他的（どちらか一方のみ指定可能）

## 参考リソース
- [AWS Provider - aws_s3_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration)
- [terraform-aws-modules - S3](https://github.com/terraform-aws-modules/terraform-aws-s3-bucket)

## 注意点
- ALB アクセスログは通常 `AWSLogs/` プレフィックスで保存されます
- CloudFront ディストリビューションのログは異なるプレフィックスを使用する場合があります
- 環境に応じて適切な expiration または transition ルールを設定してください
