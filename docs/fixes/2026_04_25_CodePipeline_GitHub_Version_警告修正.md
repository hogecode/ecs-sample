# Terraformエラー修正: CodePipeline - GitHub Source Action リージョン制限

## 修正日時
2026年4月25日

## エラーメッセージ
```
Error: creating CodePipeline Pipeline (ecs-sample-dev-pipeline): 
operation error CodePipeline: CreatePipeline, https response error StatusCode: 400, 
RequestID: fd7b0b03-56f6-4cd1-8de3-34aa0fc805d8, 
InvalidActionDeclarationException: ActionType (Category: 'Source', Provider: 'CodeStar', 
Owner: 'AWS', Version: '1') in action 'SourceAction' is not available in region 'AP_NORTHEAST_1'
```

## 警告メッセージ（元の推奨）
```
Warning: The CodePipeline GitHub version 1 action provider is no longer recommended.

Use a GitHub version 2 action (with a CodeStar Connection `aws_codestarconnections_connection`) 
as recommended instead. See https://docs.aws.amazon.com/codepipeline/latest/userguide/update-github-action-connections.html
```

## 問題の原因
AWS CodePipeline は GitHub version 1 action provider（OAuth token ベース）の廃止を推奨し、GitHub version 2 action provider（CodeStar Connection ベース）への移行を提案しています。

ただし、**CodeStar Provider は一部のリージョンでサポートされていません**。特に `ap-northeast-1` (Tokyo) リージョンでは利用できません。

## 実装した解決策
ap-northeast-1 リージョンではサポートされていないため、GitHub v1 (OAuth token) ベースの実装を採用しました。

### 最終実装内容
**ファイル:** `terraform/modules/cicd/main.tf`

```hcl
stage {
  name = "Source"

  action {
    name             = "SourceAction"
    category         = "Source"
    owner            = "ThirdParty"
    provider         = "GitHub"
    version          = "1"
    output_artifacts = ["source_output"]

    configuration = {
      Owner  = var.github_owner
      Repo   = var.github_repo
      Branch = var.environment == "prod" ? var.github_branch_main : var.github_branch_develop
      OAuthToken = var.github_token
      PollForSourceChanges = "false"
    }
  }
}
```

## リージョン互換性

| リージョン | CodeStar サポート | GitHub v1 (OAuth) |
|-----------|------------------|-------------------|
| us-east-1 | ✅ | ✅ |
| eu-west-1 | ✅ | ✅ |
| ap-northeast-1 (Tokyo) | ❌ | ✅ |
| ap-southeast-1 (Singapore) | ❌ | ✅ |

## 将来のマイグレーション
ap-northeast-1 がサポートされるようになった場合は、以下の手順で CodeStar v2 に移行できます：

1. **CodeStar Connection リソースを作成**
2. **Source action の provider を CodeStar に変更**
3. **OAuthToken を connection.arn に変更**

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

## 参考リソース
- [AWS CodePipeline - GitHub との統合](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/update-github-action-connections.html)
- [AWS CodeStar Connections - リージョン対応](https://docs.aws.amazon.com/ja_jp/dtconsole/latest/userguide/connections.html)

## 注意点
- GitHub OAuth token は `terraform/environments/dev.tfvars` で `github_token` 変数として設定する必要があります
- token は sensitive として扱われ、terraform state には保存されません
