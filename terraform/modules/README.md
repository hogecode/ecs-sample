# Terraform AWS Modules

このディレクトリには、terraform-aws-modules公式モジュールを使用したAWSインフラストラクチャのモジュール化構成が含まれています。

## モジュール一覧

### 1. ALB Module (`alb/`)
**基盤**: terraform-aws-alb v9.0
- Application Load Balancer（ALB）の管理
- パブリックALB（フロントエンド向け）
- プライベートALB（バックエンド向け）
- ターゲットグループとリスナーの設定
- HTTPS/HTTP リダイレクション機能
- パブリック/プライベートLBの統一管理

**主要な入力**:
- `project_name`: プロジェクト名
- `environment`: 環境名
- `vpc_id`: VPC ID
- `public_subnet_ids`: パブリックサブネット
- `private_api_subnet_ids`: プライベートサブネット

### 2. ECR Module (`ecr/`)
**基盤**: terraform-aws-ecr
- Elastic Container Registry（ECR）リポジトリの管理
- イメージスキャン設定
- ライフサイクルポリシーの自動化

**主要な入力**:
- `ecr_nextjs_repository_name`: Next.jsリポジトリ名
- `ecr_go_server_repository_name`: Goサーバーリポジトリ名
- `ecr_image_scan_on_push`: プッシュ時にスキャン
- `ecr_image_tag_mutability`: タグの変更不可設定

### 3. CloudWatch Module (`cloudwatch/`)
**基盤**: terraform-aws-cloudwatch
- CloudWatch ロググループの管理
- CloudWatch メトリクスアラーム
- SNS トピックの管理
- CloudTrail ログの管理（オプション）

**主要な入力**:
- `app_name`: アプリケーション名
- `environment`: 環境名
- `logs_retention_days`: ログ保持期間
- `cloudwatch_logs_kms_key_id`: KMS キー ID

### 4. Route53 Module (`route53/`)
**基盤**: terraform-aws-route53
- Route53 DNS レコード管理
- A レコード、ワイルドカードレコード対応
- ヘルスチェック管理

**主要な入力**:
- `route53_zone_id`: Route53 ゾーン ID
- `domain_name`: ドメイン名
- `alb_dns_name`: ALB DNS 名
- `alb_zone_id`: ALB ゾーン ID

### 5. Secrets Manager Module (`secrets-manager/`)
**基盤**: terraform-aws-secrets-manager
- AWS Secrets Manager でのシークレット管理
- 暗号化されたシークレット保存
- 複数のシークレット構成対応

**主要な入力**:
- `app_name`: アプリケーション名
- `environment`: 環境名
- `app_key`: アプリケーションキー
- `rds_endpoint`: RDS エンドポイント
- `secrets_kms_key_id`: KMS キー ID

### 6. Lambda Module (`lambda/`)
**基盤**: terraform-aws-lambda
- AWS Lambda 関数の管理
- VPC 統合
- IAM ロール・ポリシーの自動管理
- EventBridge トリガー対応

**主要な入力**:
- `lambda_function_name`: 関数名
- `lambda_handler`: ハンドラー（例：index.handler）
- `lambda_runtime`: ランタイム（例：python3.11）
- `lambda_source_path`: ソースコードパス
- `vpc_subnet_ids`: VPC サブネット ID

### 7. CloudFront Module (`cloudfront/`)
**基盤**: terraform-aws-cloudfront
- CloudFront ディストリビューション管理
- S3 オリジン設定
- キャッシュ動作設定
- SSL/TLS 設定

**主要な入力**:
- `s3_bucket_domain_name`: S3 バケットドメイン名
- `origin_id`: オリジン ID
- `acm_certificate_arn`: ACM 証明書 ARN
- `price_class`: 価格クラス

### 8. Auto Scaling Module (`autoscaling/`)
**基盤**: terraform-aws-autoscaling
- Auto Scaling グループ管理
- スケーリングポリシー
- CloudWatch アラーム統合

**主要な入力**:
- `autoscaling_group_name`: ASG 名
- `min_size`: 最小サイズ
- `max_size`: 最大サイズ
- `desired_capacity`: 希望容量
- `launch_template_name`: 起動テンプレート名

## 使用方法

### モジュールの呼び出し例

```hcl
module "alb" {
  source = "./modules/alb"
  
  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnets
  alb_public_security_group_id = module.security_group.alb_public_security_group_id
}

module "ecr" {
  source = "./modules/ecr"
  
  ecr_nextjs_repository_name    = var.ecr_nextjs_repository_name
  ecr_go_server_repository_name = var.ecr_go_server_repository_name
  ecr_image_scan_on_push        = var.ecr_image_scan_on_push
}
```

## 環境変数の設定

各モジュールの `variables.tf` ファイルで定義されている変数をご確認ください。

## 出力値（Outputs）

各モジュールは以下の形式で出力値を提供します：

```hcl
output "module_alb_dns_name" {
  value = module.alb.public_alb_dns_name
}

output "module_ecr_nextjs_url" {
  value = module.ecr.nextjs_repository_url
}
```

## バージョン情報

| モジュール | バージョン |
|-----------|-----------|
| terraform-aws-alb | ~> 9.0 |
| terraform-aws-ecr | ~> 1.0 |
| terraform-aws-cloudwatch | ~> 5.0 |
| terraform-aws-route53 | ~> 2.0 |
| terraform-aws-secrets-manager | ~> 1.0 |
| terraform-aws-lambda | ~> 6.0 |
| terraform-aws-cloudfront | ~> 3.0 |
| terraform-aws-autoscaling | ~> 7.0 |

## セキュリティのベストプラクティス

1. **KMS 暗号化**: Secrets Manager と CloudWatch ログは KMS キーで暗号化します
2. **IAM ロール**: Lambda と EC2 に最小権限のロールを付与します
3. **セキュリティグループ**: ALB とリソース間の通信を制限します
4. **VPC**: Lambda と RDS を VPC 内に配置します

## トラブルシューティング

### モジュールが見つからない
```bash
terraform init -upgrade
```

### 属性エラー
モジュールのドキュメントを確認し、正しい属性名を使用してください：
- terraform-aws-modules/alb/aws: `public_alb` など
- terraform-aws-modules/ecr/aws: `nextjs_ecr` など

## 参考リンク

- [terraform-aws-modules/alb/aws](https://github.com/terraform-aws-modules/terraform-aws-alb)
- [terraform-aws-modules/ecr/aws](https://github.com/terraform-aws-modules/terraform-aws-ecr)
- [terraform-aws-modules/cloudwatch/aws](https://github.com/terraform-aws-modules/terraform-aws-cloudwatch)
- [terraform-aws-modules/route53/aws](https://github.com/terraform-aws-modules/terraform-aws-route53)
- [terraform-aws-modules/secrets-manager/aws](https://github.com/terraform-aws-modules/terraform-aws-secrets-manager)
- [terraform-aws-modules/lambda/aws](https://github.com/terraform-aws-modules/terraform-aws-lambda)
- [terraform-aws-modules/cloudfront/aws](https://github.com/terraform-aws-modules/terraform-aws-cloudfront)
- [terraform-aws-modules/autoscaling/aws](https://github.com/terraform-aws-modules/terraform-aws-autoscaling)
