# Terraformエラー修正: Bastion Fargate - Output リソース参照エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: Missing resource instance key

Because aws_ecs_service.bastion has "count" set, 
its attributes must be accessed on specific instances.
```

## 問題の原因
Task Definition と Service を `count` で条件付き作成に変更したが、outputs.tf の参照を更新していませんでした。`count` を使用するリソースの属性にアクセスする場合、インデックスを指定する必要があります。

## 実装した解決策
outputs.tf の参照を更新し、`try()` 関数を使用して安全にリソースを参照するようにしました。リソースが存在しない場合は空文字列を返します。

### 修正内容
**ファイル:** `terraform/modules/compute/bastion-fargate/outputs.tf`

**修正前:**
```hcl
output "bastion_task_definition_arn" {
  description = "ARN of the Bastion task definition"
  value       = aws_ecs_task_definition.bastion.arn
}

output "bastion_service_name" {
  description = "Name of the Bastion ECS service"
  value       = aws_ecs_service.bastion.name
}
```

**修正後:**
```hcl
output "bastion_task_definition_arn" {
  description = "ARN of the Bastion task definition"
  value       = try(aws_ecs_task_definition.bastion[0].arn, "")
}

output "bastion_service_name" {
  description = "Name of the Bastion ECS service"
  value       = try(aws_ecs_service.bastion[0].name, "")
}
```

同様に他の outputs も更新します：
- `bastion_service_arn`
- `bastion_cluster_name`
- `bastion_task_definition_family`

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 影響範囲
- `terraform/modules/compute/bastion-fargate/outputs.tf` - すべての Bastion 関連の outputs

## ベストプラクティス
`count` を使用する場合、outputs では常に `try()` 関数を使用して、リソースが存在しない場合の処理を明示的に指定することをお勧めします。
