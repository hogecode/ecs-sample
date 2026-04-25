# ALB ターゲットグループ キー修正 - Blue/Green デプロイメント対応

## 概要
ECS Service で `load_balancer` ブロックに空の `target_group_arn` が渡されるエラーが発生していました。根本原因は ALB Module の outputs.tf が、定義されていない target_group キーを参照していたことです。

## 🔴 エラー内容

```
Error: Target Group ARN and Load Balancer Name cannot both be blank.

   with module.ecs.aws_ecs_service.go_server,
   on modules\compute\ecs\main.tf line 343, in resource "aws_ecs_service" "go_server":
  343: resource "aws_ecs_service" "go_server" {
```

## 🔍 根本原因

### ALB Module の定義（main.tf）
```terraform
# Next.js - Blue/Green デプロイメント用
target_groups = {
  nextjs-blue = { ... }      # ✅ 存在
  nextjs-green = { ... }     # ✅ 存在
}

# Go Server - Blue/Green デプロイメント用
target_groups = {
  go-server-blue = { ... }   # ✅ 存在
  go-server-green = { ... }  # ✅ 存在
}
```

### ALB Module の出力（outputs.tf） - **修正前**
```terraform
output "nextjs_target_group_arn" {
  value = try(module.public_alb.target_groups["nextjs"].arn, "")  # ❌ キー不一致！
}

output "go_server_target_group_arn" {
  value = try(module.private_alb.target_groups["go-server"].arn, "") # ❌ キー不一致！
}
```

## ✅ 修正内容

### terraform/modules/network/alb/outputs.tf

#### Next.js ターゲットグループ（修正前 → 修正後）
```terraform
# 修正前
output "nextjs_target_group_arn" {
  value = try(module.public_alb.target_groups["nextjs"].arn, "")
}

# 修正後
output "nextjs_target_group_arn" {
  value = try(module.public_alb.target_groups["nextjs-blue"].arn, "")
}

# 追加：Blue/Green デプロイメント用の明示的な出力
output "nextjs_blue_target_group_arn" {
  value = try(module.public_alb.target_groups["nextjs-blue"].arn, "")
}

output "nextjs_green_target_group_arn" {
  value = try(module.public_alb.target_groups["nextjs-green"].arn, "")
}
```

#### Go Server ターゲットグループ（修正前 → 修正後）
```terraform
# 修正前
output "go_server_target_group_arn" {
  value = try(module.private_alb.target_groups["go-server"].arn, "")
}

# 修正後
output "go_server_target_group_arn" {
  value = try(module.private_alb.target_groups["go-server-blue"].arn, "")
}

# 追加：Blue/Green デプロイメント用の明示的な出力
output "go_server_blue_target_group_arn" {
  value = try(module.private_alb.target_groups["go-server-blue"].arn, "")
}

output "go_server_green_target_group_arn" {
  value = try(module.private_alb.target_groups["go-server-green"].arn, "")
}
```

## 📊 影響範囲

### 修正ファイル
- `terraform/modules/network/alb/outputs.tf`

### 依存するリソース
- `terraform/modules/compute/ecs/main.tf`
  - `aws_ecs_service.nextjs` の load_balancer.target_group_arn
  - `aws_ecs_service.go_server` の load_balancer.target_group_arn

### 新しい出力
- `nextjs_blue_target_group_arn`
- `nextjs_blue_target_group_name`
- `nextjs_green_target_group_arn`
- `nextjs_green_target_group_name`
- `go_server_blue_target_group_arn`
- `go_server_blue_target_group_name`
- `go_server_green_target_group_arn`
- `go_server_green_target_group_name`

## 🎯 修正の効果

### Before（修正前）
```
ALB ターゲットグループ定義 (main.tf)
  ├─ nextjs-blue, nextjs-green
  └─ go-server-blue, go-server-green

ALB outputs.tf が参照するキー
  ├─ "nextjs" ❌ (存在しない)
  └─ "go-server" ❌ (存在しない)

結果
  └─ try() は "" を返す → ECS Service エラー
```

### After（修正後）
```
ALB ターゲットグループ定義 (main.tf)
  ├─ nextjs-blue, nextjs-green
  └─ go-server-blue, go-server-green

ALB outputs.tf が参照するキー
  ├─ "nextjs-blue" ✅ (存在)
  ├─ "nextjs-green" ✅ (存在)
  ├─ "go-server-blue" ✅ (存在)
  └─ "go-server-green" ✅ (存在)

結果
  └─ 正しい ARN が ECS Service に渡される
```

## 🔧 Terraform Plan/Apply への影響

### 削除されるリソース
- `module.alb.module.public_alb.aws_lb_target_group.this["nextjs"]`
- `module.alb.module.private_alb.aws_lb_target_group.this["go-server"]`

### 作成されるリソース
- なし（Blue/Green ターゲットグループは既存）

### 修正されるリソース
- `module.ecs.aws_ecs_service.nextjs` - load_balancer.target_group_arn を修正
- `module.ecs.aws_ecs_service.go_server` - load_balancer.target_group_arn を修正

## 📝 デプロイ手順

```bash
# Plan を確認
terraform plan -out=tfplan

# 変更を適用
terraform apply tfplan
```

## ⚠️ 注意事項

### Blue/Green デプロイメント
- ECS Service は `nextjs-blue` / `go-server-blue` にトラフィックを送信
- CodeDeploy が Blue/Green 切り替え時に green ターゲットグループにトラフィックを切り替え
- `ignore_desired_count_changes` と `ignore_task_definition_changes` が有効なため、Terraform は CodeDeploy の変更を上書きしない

### 旧キー参照
- 古いコード/ドキュメントで `["nextjs"]` や `["go-server"]` を参照している場合は、以下に更新：
  - `module.public_alb.target_groups["nextjs-blue"]`
  - `module.private_alb.target_groups["go-server-blue"]`

## 参考
- Terraform AWS ALB Module: https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/
- ECS Service Load Balancer: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#load_balancer
