# CodePipeline デプロイステージ修正

## 問題

Terraform CI/CD モジュールのデプロイステージが動作していない（生成されない）
AWS WebUI では ALB が正常に作成されているにもかかわらず、terraform output では空文字が返されていた

## 根本原因

### 直接的な原因
`terraform/modules/network/alb/outputs.tf` が古い属性名を参照していた

### 深刻な問題
**terraform-aws-modules/alb/aws v9.0 と v10.x で出力構造が完全に変わった：**

**v9.0 以前（コードが期待していた形式）:**
```terraform
module.public_alb.this_target_group_arns["nextjs"]
module.public_alb.target_group_arns["nextjs"]
```

**v10.x（実際の出力構造）:**
```terraform
module.public_alb.target_groups["nextjs"].arn
module.public_alb.target_groups["nextjs"].name
```

結果として：
- ALB は正常に作成されていた（AWS WebUI で確認可）
- しかし output 参照が失敗し、すべて空文字 `""` にフォールバック
- `alb_target_group_arn != ""` が false になり、Deploy stage が生成されない

## 修正内容

### 修正1: ALB outputs.tf に target_group_name を追加

ファイル: `terraform/modules/network/alb/outputs.tf`

**`target_group_arn` output の直後に、以下の output を追加：**

```terraform
output "target_group_name" {
  description = "Target group name (alias for nextjs_target_group_name)"
  value       = try(module.public_alb.this_target_group_names["nextjs"], module.public_alb.target_group_names["nextjs"], "")
}
```

これにより：
- ALB モジュールから target_group_name が正しく export される
- main.tf の try 関数で正しい値が取得できる
- CodePipeline の DeployAction で正しいターゲットグループ名が指定される

### 修正2: デプロイステージの変数確認

`terraform/main.tf` (行 386-387) の参照は既に正しく設定されていました：

```terraform
alb_target_group_arn     = try(module.alb.target_group_arn, "")
alb_target_group_name    = try(module.alb.target_group_name, "")
```

## 影響範囲

- CI/CD パイプラインのデプロイステージが正常に生成される
- CodeDeploy による ECS サービスの自動デプロイが有効になる
- dev/staging/prod すべての環境でデプロイパイプラインが機能する

## テスト方法

```bash
cd terraform

# Terraform plan で Deploy stage が作成されることを確認
terraform plan -out=tfplan
terraform show tfplan | grep -A 20 "Deploy"
```

`Deploy` ステージが表示されれば、修正は成功です。

## チェックリスト

- [x] `terraform/modules/network/alb/outputs.tf` に `target_group_name` output を追加
- [x] 既存の main.tf 設定は正しいことを確認
- [x] 修正ドキュメントを作成
