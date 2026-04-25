# Terraformエラー修正: CodePipeline - Artifact Bucket 設定エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating CodePipeline Pipeline (ecs-sample-dev-pipeline): 
operation error CodePipeline: CreatePipeline, 1 validation error(s) found.
- missing required field, CreatePipelineInput.Pipeline.ArtifactStore.Location.
```

## 問題の原因
CodePipeline の `artifact_store.location` に空の値が渡されていました。

terraform/main.tf line 361 で：
```hcl
artifact_bucket_name = try(module.storage.alb_logs_bucket_id, "")
```

storage モジュールの出力には `alb_logs_bucket_id` ではなく `alb_logs_bucket_name` が定義されているため、`try()` が失敗して空文字列が返されていました。

## 実装した解決策
terraform/main.tf で artifact_bucket_name を正しい出力変数に変更しました。

### 修正内容
**ファイル:** `terraform/main.tf` line 357-362

修正前：
```hcl
  # ALB Configuration
  alb_target_group_arn     = try(module.alb.target_group_arn, "")

  # Artifact Storage
  artifact_bucket_name     = try(module.storage.alb_logs_bucket_id, "")
  kms_key_id              = try(module.storage.artifact_bucket_kms_key_id, "")
```

修正後：
```hcl
  # ALB Configuration
  alb_target_group_arn     = try(module.alb.target_group_arn, "")
  alb_target_group_name    = try(module.alb.target_group_name, "")

  # Artifact Storage
  artifact_bucket_name     = module.storage.app_filesystem_bucket_name
  kms_key_id              = try(module.storage.artifact_bucket_kms_key_id, "")
```

## 変更内容の詳細

### 1. artifact_bucket_name の修正
- **変更前:** `try(module.storage.alb_logs_bucket_id, "")`
  - 存在しない出力変数を参照
  - 常に空文字列を返す

- **変更後:** `module.storage.app_filesystem_bucket_name`
  - app_filesystem_bucket_name は storage モジュールで正しく定義されている
  - CodePipeline の artifact を保存するために app_filesystem_bucket を使用

### 2. alb_target_group_name の追加
CodeDeploy Deployment Group で必要な変数を追加しました。

## storage モジュールの出力変数
`terraform/modules/storage/s3/outputs.tf`:
```hcl
output "app_filesystem_bucket_name" {
  description = "Name of the app filesystem bucket"
  value       = module.app_filesystem.s3_bucket_id
}
```

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

このエラーが解消され、CodePipeline が正常に作成されることを確認できます。
