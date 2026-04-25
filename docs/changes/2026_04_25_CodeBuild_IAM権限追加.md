# CodeBuild IAM 権限追加：ecr:BatchCheckLayerAvailability

## 概要

CodeBuild が ECR へのイメージ push に失敗していた問題を解決するため、IAM ポリシーに `ecr:BatchCheckLayerAvailability` 権限を追加しました。

## 問題の原因

CodeBuild が ECR にイメージをプッシュする際に、以下のエラーが発生していました：

```
error parsing HTTP 403 response body: unexpected end of JSON input: ""
```

原因は CodeBuild IAM ロールに `ecr:BatchCheckLayerAvailability` 権限がなかったためです。

## 修正内容

### 修正ファイル
`terraform/modules/cicd/main.tf` の CodeBuild IAM ポリシー

### 追加した権限
```json
"ecr:BatchCheckLayerAvailability"
```

### 完全な ECR アクション一覧
修正後の CodeBuild IAM ポリシーに含まれる ECR アクション：

```json
"Action": [
  "ecr:GetAuthorizationToken",
  "ecr:BatchGetImage",
  "ecr:GetDownloadUrlForLayer",
  "ecr:PutImage",
  "ecr:InitiateLayerUpload",
  "ecr:UploadLayerPart",
  "ecr:CompleteLayerUpload",
  "ecr:DescribeRepositories",
  "ecr:ListImages",
  "ecr:BatchCheckLayerAvailability"  // ← 新規追加
]
```

## Terraform 適用結果

```
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

CodeBuild IAM ロールポリシーが正常に更新されました。

## 期待される効果

✅ CodeBuild で ECR へのイメージ push が成功するようになります
✅ 403 エラーが解決されます
✅ CI/CD パイプラインが正常に動作します

## 動作確認

修正後、以下の手順で動作確認してください：

1. CodeBuild プロジェクトでビルドを再実行
2. ビルドログで push が成功することを確認
3. ECR リポジトリにイメージが登録されていることを確認

## 関連資料

- **AWS ECR IAM アクション**：https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/APIReference/API_Operations.html
- **CodeBuild IAM ポリシー**：https://docs.aws.amazon.com/codebuild/latest/userguide/security-iam.html

## 修正日時

2026年4月25日 午後4時46分
