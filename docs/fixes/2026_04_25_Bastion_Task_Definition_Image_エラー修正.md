# Terraformエラー修正: Bastion Task Definition - Image エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating ECS Task Definition (ecs-sample-bastion-dev): 
ClientException: Container.image should not be null or empty.
```

## 問題の原因
`bastion_image_uri` が空の場合、Task Definition が null image で作成されていました。

## 実装した解決策
Task Definition と Service に `count` を追加し、`bastion_image_uri` が空でない場合のみ作成するようにしました。

### 修正内容
**ファイル:** `terraform/modules/compute/bastion-fargate/main.tf`

**修正前:**
```hcl
resource "aws_ecs_task_definition" "bastion" {
  # bastion_image_uri が空でも作成される
}

resource "aws_ecs_service" "bastion" {
  # 常に作成される
}
```

**修正後:**
```hcl
resource "aws_ecs_task_definition" "bastion" {
  count = var.bastion_image_uri != "" ? 1 : 0
  # bastion_image_uri が空でない場合のみ作成
}

resource "aws_ecs_service" "bastion" {
  count = var.bastion_image_uri != "" ? 1 : 0
  # bastion_image_uri が空でない場合のみ作成
}
```

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 注意点
- `bastion_image_uri` が空の場合、Bastion Fargate リソースは作成されません
- Bastion が不要な場合は、`bastion_image_uri = ""` で設定してください
- Bastion を使用する場合は、`bastion_image_uri` に有効な ECR イメージ URI を指定してください
