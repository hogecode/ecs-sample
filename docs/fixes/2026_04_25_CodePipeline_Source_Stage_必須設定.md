# Terraformエラー修正: CodePipeline - Source Stage 必須設定

## エラーメッセージ
```
Error: creating CodePipeline Pipeline (ecs-sample-dev-pipeline): 
operation error CodePipeline: CreatePipeline, https response error StatusCode: 400, 
InvalidStructureException: Pipeline should start with a stage that only contains source actions
```

## 問題の原因
AWS CodePipeline では、最初のステージ（最初に実行されるステージ）は **必ず Source action を含む必要があります**。

現在の実装では、`github_token` が空の場合、Source stage が作成されず、Build stage が最初のステージになってしまいます。これが AWS API エラーの原因です。

## 解決方法

### 方法1：github_token を dev.tfvars で設定する（推奨）

`terraform/environments/dev.tfvars` に GitHub OAuth token を設定します：

```hcl
# CI/CD
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

GitHub token を取得する手順：
1. GitHub にログイン
2. Settings → Developer settings → Personal access tokens → Tokens (classic)
3. "Generate new token (classic)" をクリック
4. `repo` スコープを選択
5. トークンをコピー
6. `dev.tfvars` に設定

### 方法2：CodePipeline を条件付きで作成する（代替方法）

`terraform/modules/cicd/main.tf` で CodePipeline 全体を count で条件付き化：

```hcl
resource "aws_codepipeline" "pipeline" {
  count    = var.github_token != "" ? 1 : 0
  # ... rest of config
}
```

ただし、cicd module の出力も全て条件付きにする必要があります。

## 推奨される設定

GitHub token を `terraform/environments/dev.tfvars` に設定することをお勧めします：

```hcl
# CI/CD
github_token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

これにより、開発環境で自動的に CI/CD パイプラインが構築されます。

## 注意点
- GitHub token は sensitive として扱われ、terraform state には平文で保存されません
- token は絶対に Git にコミットしないでください
- `.gitignore` で `dev.tfvars` が除外されていることを確認してください

## 検証方法
```bash
cd terraform
terraform plan -var-file=environments/dev.tfvars
```

`github_token` が正しく設定されていれば、CodePipeline が正常に作成されます。
