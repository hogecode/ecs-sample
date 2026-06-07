# RDS権限修正 - Bastion EC2 IAMロール

## 問題
Bastion EC2インスタンスから以下のエラーが発生していました：

```
An error occurred (AccessDenied) when calling the DescribeDBInstances operation: 
User: arn:aws:sts::885545925004:assumed-role/bastion-ec2-role-20260430122306604800000001/i-097c68a813c7720f6 
is not authorized to perform: rds:DescribeDBInstances on resource: arn:aws:rds:ap-northeast-1:885545925004:db:*
```

## 原因
Bastion EC2のIAMロール (`bastion_role`) には以下の権限しかありませんでした：
- `AmazonSSMManagedInstanceCore` (Session Manager用)
- `CloudWatchAgentServerPolicy` (CloudWatch ログ用)
- `ecr:GetAuthorizationToken` (ECR用)
- `secretsmanager:GetSecretValue` (Secrets Manager用)

**RDS権限が追加されていませんでした。**

## 解決方法

### 修正内容
`terraform/modules/compute/bastion-ec2/main.tf` の `bastion_secrets_policy` ポリシーに以下のRDS権限を追加しました：

```json
{
  "Effect": "Allow",
  "Action": [
    "rds:DescribeDBInstances",
    "rds:DescribeDBClusters",
    "rds:DescribeDBParameterGroups",
    "rds:DescribeDBSecurityGroups",
    "rds:ListTagsForResource"
  ],
  "Resource": "*"
}
```

### 適用手順

1. **変更を確認する**
```bash
cd terraform
terraform plan -target=module.bastion
```

2. **変更を適用する**
```bash
terraform apply -target=module.bastion
```

3. **Bastion EC2インスタンスを再起動する（推奨）**
   - AWS ConsoleからEC2インスタンスを再起動、または
   - AWS CLIで実行：
   ```bash
   aws ec2 reboot-instances --instance-ids i-097c68a813c7720f6 --region ap-northeast-1
   ```

4. **新しい権限をテストする**
```bash
# SSM Session Managerで接続
aws ssm start-session --target i-097c68a813c7720f6 --region ap-northeast-1

# Bastion内で実行
aws rds describe-db-instances --region ap-northeast-1 --query "DBInstances[*].Endpoint.Address"
```

## 追加されたRDS権限の説明

| 権限 | 目的 |
|------|------|
| `rds:DescribeDBInstances` | RDSインスタンスの詳細情報を取得（エンドポイント、ポート、ステータスなど） |
| `rds:DescribeDBClusters` | RDS クラスタの情報を取得 |
| `rds:DescribeDBParameterGroups` | DBパラメータグループの情報を取得 |
| `rds:DescribeDBSecurityGroups` | DBセキュリティグループの情報を取得 |
| `rds:ListTagsForResource` | RDSリソースのタグを取得 |

## セキュリティに関する注記

- 権限は`Resource: "*"`で設定されています（読み取り専用操作のため）
- より制限したい場合は、特定のRDSインスタンスのARNを指定できます：
  ```
  "Resource": "arn:aws:rds:ap-northeast-1:885545925004:db:your-db-instance-name"
  ```

## 関連ファイル
- `terraform/modules/compute/bastion-ec2/main.tf` - IAMロールポリシー定義

## 参考リンク
- [AWS RDS IAM Database Authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [RDS API Permissions Reference](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/security-iam-awsmanaged-policies.html)
