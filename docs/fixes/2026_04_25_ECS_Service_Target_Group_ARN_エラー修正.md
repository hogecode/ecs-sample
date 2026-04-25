# Terraformエラー修正: ECS Service - Target Group ARN エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating ECS Service (ecs-sample-nextjs-service): operation error ECS: CreateService, 
https response error StatusCode: 400, RequestID: a16344b0-4a46-4d1d-9ba8-a06801a85a31, 
InvalidParameterException: Target Group ARN and Load Balancer Name cannot both be blank.
```

## 問題の原因
- ALB モジュールが `nextjs_target_group_arn` と `go_server_target_group_arn` に空の値を返していた
- ECS Service の `load_balancer` block が常に実行されていたため、空の target_group_arn が渡されていた

## 実装した解決策
`load_balancer` block を `dynamic` ブロックに変更し、target_group_arn が空でない場合のみ実行するようにしました。

### 修正内容
**ファイル:** `terraform/modules/compute/ecs/main.tf`

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

同様に `go_server_target_group_arn` についても同じ修正を適用します。

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 注意点
- target_group_arn が空の場合、ALB を使用しない構成になります
- この場合、ECS Service は ALB なしで起動します
- 本番環境では適切な target_group_arn を指定してください
