# Terraformエラー修正: Bastion Fargate - IAM Policy エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: putting IAM Role (bastion-task-execution-*) Policy: 
MalformedPolicyDocument: Policy statement must contain resources.
```

## 問題の原因
IAM Policy の Statement に空の Resource 配列が指定されていました。`rds_master_password_secret_arn` が空の場合、Resource が空配列になっていました。

## 実装した解決策
`concat()` 関数を使用して、`rds_master_password_secret_arn` が空の場合は Statement を除外するようにしました。

### 修正内容
**ファイル:** `terraform/modules/compute/bastion-fargate/main.tf`

Secrets Manager へのアクセス権限が必要な場合のみ Statement を追加し、不要な場合は追加しないようにしました：

```hcl
policy = jsonencode({
  Version = "2012-10-17"
  Statement = concat(
    [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          # ...
        ]
        Resource = "*"
      }
    ],
    var.rds_master_password_secret_arn != "" ? [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [var.rds_master_password_secret_arn]
      }
    ] : []
  )
})
```

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 影響範囲
- `terraform/modules/compute/bastion-fargate/main.tf` - Bastion Task Execution Role Policy
