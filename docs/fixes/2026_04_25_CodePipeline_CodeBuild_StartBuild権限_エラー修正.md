# CodePipeline CodeBuild StartBuild権限不足 - エラー修正

## エラー内容

CodePipelineがBuildステージを実行する際に以下のエラーが発生：

```
Error calling startBuild: User: arn:aws:sts::885545925004:assumed-role/codepipeline-role-xxxxx/xxxxx 
is not authorized to perform: codebuild:StartBuild on resource: 
arn:aws:codebuild:ap-northeast-1:885545925004:project/ecs-sample-dev-build 
because no identity-based policy allows the codebuild:StartBuild action
```

## 原因

CodePipelineサービスロールのIAMポリシーに、CodeBuildプロジェクトを**起動（StartBuild）** するための権限がなかった。

**修正前のアクション:**
- ❌ `codebuild:StartBuild` がない

**修正前のポリシー:**
```json
{
  "Effect": "Allow",
  "Action": [
    "codebuild:BatchGetBuilds",
    "codebuild:BatchGetReports",
    "codebuild:CreateReport",
    "codebuild:CreateReportGroup",
    "codebuild:UpdateReport",
    "codebuild:BatchPutTestReports"
  ],
  "Resource": "*"
}
```

## 修正内容

**修正ファイル:** `terraform/modules/cicd/main.tf`

**変更箇所:** `aws_iam_role_policy.codepipeline_policy` (行109-173)

### 修正前
```hcl
{
  Effect = "Allow"
  Action = [
    "codebuild:BatchGetBuilds",
    "codebuild:BatchGetReports",
    "codebuild:CreateReport",
    "codebuild:CreateReportGroup",
    "codebuild:UpdateReport",
    "codebuild:BatchPutTestReports"
  ]
  Resource = "*"
}
```

### 修正後
```hcl
{
  Effect = "Allow"
  Action = [
    "codebuild:StartBuild",              # ← 追加
    "codebuild:BatchGetBuilds",
    "codebuild:BatchGetReports",
    "codebuild:CreateReport",
    "codebuild:CreateReportGroup",
    "codebuild:UpdateReport",
    "codebuild:BatchPutTestReports"
  ]
  Resource = "*"
}
```

## 修正の詳細説明

### StartBuildアクションが必要な理由

CodePipelineのBuildステージでCodeBuildプロジェクトを実行するには、以下の一連の操作が必要：

1. **startBuild**: CodeBuildプロジェクトを起動 ← **この権限が足りなかった**
2. **batchGetBuilds**: ビルド状態を確認
3. **batchGetReports**: レポート取得
4. **createReport**: レポート作成

CodePipelineロールがBuildステージを実行する際、以下のシーケンスで動作：

```
CodePipeline
    ↓
startBuild (CodeBuildプロジェクト起動) ← 権限不足でここで失敗
    ↓
batchGetBuilds (完了待機)
    ↓
batchGetReports (結果確認)
```

`startBuild` 権限がないと、CodePipelineはプロジェクトを起動すらできません。

## 修正による影響

### ✅ 修正による改善

- CodePipelineがBuildステージを正常に実行できるようになる
- Buildステージ完了後、Scanステージ→Deployステージが順序通り実行される
- CI/CDパイプラインが完全に機能するようになる

### 🔒 セキュリティ

現在は `Resource = "*"` で全CodeBuildプロジェクトへのアクセスを許可していますが、本番運用時には以下のように限定することを推奨：

```hcl
Resource = [
  "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${local.codebuild_build_project}",
  "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${local.codebuild_scan_project}"
]
```

## 修正後の動作確認

修正後は以下の手順で確認：

### 1. Terraform Apply
```bash
cd terraform
terraform apply
```

### 2. CodePipeline実行確認（AWSコンソール）

1. AWS管理コンソール → CodePipeline
2. `ecs-sample-dev-pipeline` を選択
3. **Build** ステージが **Success** 状態で完了する
4. **Scan** → **Deploy** ステージが続行実行される

### 3. CloudWatch Logs確認

```bash
# CodeBuildビルドログ確認
aws logs tail /aws/codebuild/ecs-sample-dev-build --follow
```

ビルドログに以下が表示される：
- ✅ `[INFO] Build started`
- ✅ Docker イメージビルド進捗
- ✅ ECR プッシュ進捗
- ✅ `[INFO] Build completed successfully`

## 関連ドキュメント

- [AWS IAM - CodeBuild アクション](https://docs.aws.amazon.com/ja_jp/IAM/latest/UserGuide/list_awscodebuild.html)
- [AWS CodePipeline - ベストプラクティス](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/best-practices.html)
- [CodeBuild 統合 - CodePipeline](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/action-reference-CodeBuild.html)

## チェックリスト

- [x] CodePipelineロールのIAMポリシーに `codebuild:StartBuild` を追加
- [x] Terraform適用予定
- [ ] CodePipelineがBuildステージを正常に実行（terraform apply後に確認）
- [ ] ScanステージとDeployステージが順序通り実行される
