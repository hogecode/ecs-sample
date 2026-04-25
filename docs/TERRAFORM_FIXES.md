# Terraform エラー修正ドキュメント

## 修正日時
2026年4月25日

## 修正内容

### 1. ECS Service - Target Group ARN エラー修正

**エラーメッセージ:**
```
Error: creating ECS Service (ecs-sample-nextjs-service): operation error ECS: CreateService, 
https response error StatusCode: 400, RequestID: a16344b0-4a46-4d1d-9ba8-a06801a85a31, 
InvalidParameterException: Target Group ARN and Load Balancer Name cannot both be blank.
```

**原因:**
- ALB モジュールが `nextjs_target_group_arn` と `go_server_target_group_arn` に空の値を返していた
- ECS Service の `load_balancer` block が常に実行されていたため、空の target_group_arn が渡されていた

**修正内容:**
- ファイル: `terraform/modules/compute/ecs/main.tf`
- 変更: `load_balancer` block を `dynamic` ブロックに変更
- 条件: `target_group_arn != ""` の場合のみ load_balancer block を作成

**修正前:**
```hcl
load_balancer {
  target_group_arn = var.nextjs_target_group_arn
  container_name   = "${var.project_name}-nextjs"
  container_port   = var.nextjs_container_port
}
```

**修正後:**
```hcl
dynamic "load_balancer" {
  for_each = var.nextjs_target_group_arn != "" ? [1] : []
  content {
    target_group_arn = var.nextjs_target_group_arn
    container_name   = "${var.project_name}-nextjs"
    container_port   = var.nextjs_container_port
  }
}
```

### 2. RDS - ストレージサイズと IOPS 設定エラー修正

**エラーメッセージ:**
```
Error: creating RDS DB Instance (ecs-sample-db-dev): operation error RDS: CreateDBInstance, 
https response error StatusCode: 400, RequestID: 23f50360-e5af-4c3f-880b-1b62cd8d94cd, 
api error InvalidParameterCombination: You can't specify IOPS or storage throughput for engine mysql 
and a storage size less than 400.
```

**原因:**
- MySQL エンジンでストレージサイズが 100GB（dev.tfvars で設定）の場合、storage_throughput (125) を指定できない
- AWS RDS の制約：MySQL で IOPS/スループットを指定する場合、allocated_storage は最低 400GB が必要

**修正内容:**
- ファイル: `terraform/modules/database/rds/main.tf`
- 変更: `storage_throughput` を条件付きで設定
- 条件: `allocated_storage >= 400` の場合のみ throughput を設定

**修正前:**
```hcl
storage_throughput   = 125
```

**修正後:**
```hcl
storage_throughput   = var.rds_allocated_storage >= 400 ? 125 : null
```

## 検証方法

修正後、以下のコマンドで Terraform を実行：

```bash
# Terraform の計画を確認
cd terraform
terraform plan -var-file=environments/dev.tfvars

# 問題がなければ apply
terraform apply -var-file=environments/dev.tfvars
```

## 注意点

1. **ECS Service**: target_group_arn が空の場合、ALB を使用しない構成になります
   - この場合、ECS Service は ALB なしで起動します
   - 本番環境では適切な target_group_arn を指定してください

2. **RDS**: allocated_storage < 400GB の場合、storage_throughput は自動的に null に設定されます
   - 開発環境で小さいストレージサイズを使用する場合、パフォーマンスは制限されます
   - 必要に応じて、本番環境で allocated_storage >= 400GB に増加させてください

### 3. Bastion Fargate - IAM Policy エラー修正

**エラーメッセージ:**
```
Error: putting IAM Role (bastion-task-execution-*) Policy: 
MalformedPolicyDocument: Policy statement must contain resources.
```

**原因:**
- IAM Policy の Statement に空の Resource 配列が指定されていた
- `rds_master_password_secret_arn` が空の場合、Resource が空配列になっていた

**修正内容:**
- ファイル: `terraform/modules/compute/bastion-fargate/main.tf`
- 変更: `concat()` を使用して、rds_master_password_secret_arn が空の場合は Statement を除外

### 4. Bastion Task Definition - Image エラー修正

**エラーメッセージ:**
```
Error: creating ECS Task Definition (ecs-sample-bastion-dev): 
ClientException: Container.image should not be null or empty.
```

**原因:**
- `bastion_image_uri` が空の場合、Task Definition が null image で作成されていた

**修正内容:**
- ファイル: `terraform/modules/compute/bastion-fargate/main.tf`
- 変更: Task Definition と Service に `count` を追加
- 条件: `bastion_image_uri != ""` の場合のみ作成

### 5. RDS CloudWatch Alarm - DB Instance ID エラー修正

**エラーメッセージ:**
```
Error: creating CloudWatch Metric Alarm: 
ValidationError: Value '' at 'dimensions.1.member.value' failed to satisfy constraint: 
Member must have length greater than or equal to 1
```

**原因:**
- terraform-aws-modules の RDS モジュールから返された DB Instance ID が空だった
- CloudWatch Alarm が作成される際、空の DBInstanceIdentifier が dimension に含まれていた

**修正内容:**
- ファイル: `terraform/modules/database/rds/main.tf`
- 変更: 3つの CloudWatch Alarm に `count` を追加
- 条件: `db_instance_id != ""` の場合のみ作成

### 6. Bastion Fargate - Output リソース参照エラー修正

**エラーメッセージ:**
```
Error: Missing resource instance key

Because aws_ecs_service.bastion has "count" set, 
its attributes must be accessed on specific instances.
```

**原因:**
- Task Definition と Service を `count` で条件付き作成に変更したが、outputs.tf の参照を更新していなかった

**修正内容:**
- ファイル: `terraform/modules/compute/bastion-fargate/outputs.tf`
- 変更: `aws_ecs_service.bastion` と `aws_ecs_task_definition.bastion` への参照を更新
- 使用: `try()` 関数で安全に参照し、リソースが存在しない場合は空文字列を返す

## 参考資料

- [AWS RDS MySQL - IOPS と Storage Throughput の制限](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html)
- [Terraform - aws_ecs_service リソース](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)
- [IAM ポリシー構文](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_statement.html)
