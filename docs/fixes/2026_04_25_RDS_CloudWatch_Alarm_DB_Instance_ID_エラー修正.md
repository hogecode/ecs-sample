# Terraformエラー修正: RDS CloudWatch Alarm - DB Instance ID エラー

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating CloudWatch Metric Alarm: 
ValidationError: Value '' at 'dimensions.1.member.value' failed to satisfy constraint: 
Member must have length greater than or equal to 1
```

## 問題の原因
terraform-aws-modules の RDS モジュールから返された DB Instance ID が空だった。CloudWatch Alarm が作成される際、空の DBInstanceIdentifier が dimension に含まれていました。

## 実装した解決策
CloudWatch Alarm に `count` を追加し、DB Instance ID が空でない場合のみ作成するようにしました。

### 修正内容
**ファイル:** `terraform/modules/database/rds/main.tf`

3つの CloudWatch Alarm に以下の修正を適用します：

**修正前:**
```hcl
module "cloudwatch_metric_alarm_cpu" {
  source = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  # DB Instance ID が空でも作成される
}
```

**修正後:**
```hcl
module "cloudwatch_metric_alarm_cpu" {
  count  = var.db_instance_id != "" ? 1 : 0
  source = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  # DB Instance ID が空でない場合のみ作成
}
```

同様に以下の Alarm に適用：
- CPU Utilization Alarm
- Database Connections Alarm
- Free Storage Space Alarm

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 注意点
- DB Instance ID が空の場合、CloudWatch Alarm は作成されません
- RDS モジュールが DB Instance を作成する場合、その ID は自動的に outputs で提供されます
- 監視が必要な場合は、RDS モジュールが正しく DB Instance を作成していることを確認してください
