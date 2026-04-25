# CodeDeploy アーティファクト参照修正 - build_output:: プリフィックス削除

## 概要
Terraform の CodePipeline 設定で、CodeDeploy アーティファクト参照に `build_output::` プリフィックスが付いていましたが、ローカルファイル参照に変更したため削除しました。

## 🔴 修正前の問題

### terraform/modules/cicd/main.tf の誤り

```terraform
# Next.js Deployment
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"              # ❌ 誤り
  TaskDefinitionTemplateArtifact = "build_output::nextjs-taskdef.json" # ❌ 誤り
}

# Go Server Deployment
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"              # ❌ 誤り
  TaskDefinitionTemplateArtifact = "build_output::go_server_taskdef.json" # ❌ 誤り
}
```

### なぜ誤りなのか？

`build_output::` は以下の場合に使用：
- buildspec.yaml で **動的に生成** される一時ファイル
- CodeBuild の output_artifacts から出力されるファイル

**しかし今回は:**
- ✅ appspec.yaml → **ローカルファイル** （Git管理）
- ✅ nextjs-taskdef.json → **ローカルファイル** （Git管理）
- ✅ go-server-taskdef.json → **ローカルファイル** （Git管理）

ローカルで管理されているため、`build_output::` プリフィックスは不要。

## ✅ 修正内容

### terraform/modules/cicd/main.tf

#### Next.js Deployment
**修正前:**
```terraform
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"              # ❌
  TaskDefinitionTemplateArtifact = "build_output::nextjs-taskdef.json" # ❌
}
```

**修正後:**
```terraform
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "appspec.yaml"              # ✅
  TaskDefinitionTemplateArtifact = "nextjs-taskdef.json" # ✅
}
```

#### Go Server Deployment
**修正前:**
```terraform
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"              # ❌
  TaskDefinitionTemplateArtifact = "build_output::go_server_taskdef.json" # ❌
}
```

**修正後:**
```terraform
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "appspec.yaml"              # ✅
  TaskDefinitionTemplateArtifact = "go-server-taskdef.json" # ✅
}
```

## 📊 修正の効果

| 項目 | 修正前 | 修正後 |
|-----|--------|--------|
| **AppSpec 参照** | `build_output::appspec.yaml` | `appspec.yaml` ✅ |
| **Next.js TaskDef 参照** | `build_output::nextjs-taskdef.json` | `nextjs-taskdef.json` ✅ |
| **Go Server TaskDef 参照** | `build_output::go-server-taskdef.json` | `go-server-taskdef.json` ✅ |
| **参照方法** | 動的生成（buildspec） | ローカルファイル（Git） ✅ |

## 🔄 デプロイフロー（修正後）

```
Git リポジトリ
├─ appspec.yaml
├─ nextjs-taskdef.json
└─ go-server-taskdef.json
    ↓ (チェックアウト時に取得)
CodeBuild (buildspec.yaml)
├─ Docker イメージ ビルド＆ECR Push
└─ ローカルファイルを build_output に含める
    ↓ (build_output フォルダにコピー)
S3 アーティファクトストア
├─ appspec.yaml
├─ nextjs-taskdef.json
└─ go-server-taskdef.json
    ↓
CodePipeline Deploy
├─ "appspec.yaml" を読み込み
├─ "nextjs-taskdef.json" を読み込み
└─ CodeDeploy に渡す ✅
    ↓
CodeDeploy Blue/Green
└─ デプロイメント実行
```

## 💡 `build_output::` プリフィックスの使い分け

### `build_output::` を使う場合（元の実装）
```terraform
TaskDefinitionTemplateArtifact = "build_output::taskdef.json"
```

- buildspec.yaml で **動的に生成** される
- 例: cat EOF で作成
- 毎回ビルド時に作成される
- 変更追跡が困難

### プリフィックスなし（修正後）✅
```terraform
TaskDefinitionTemplateArtifact = "taskdef.json"
```

- **ローカルで管理** されたファイル
- Git に保存
- 変更履歴が明確
- IDE のサポート機能が使える

## 🎯 ベストプラクティス

### ローカル管理が推奨される理由

| 観点 | 動的生成 | ローカル管理 ✅ |
|-----|---------|---------|
| **保守性** | buildspec.yaml 内で散乱 | 独立したファイル |
| **Git 履歴** | buildspec.yaml に含まれる | 個別に追跡 |
| **IDE サポート** | YAML内JSON（困難） | ネイティブ |
| **環境別対応** | ブランチ全体で管理 | ファイル単位 |
| **検証** | スキーム検証が難しい | yamllint / jq 可能 |

## ✨ 実装のポイント

### CodeBuild の動作
```
1. GitHub から ソースコード チェックアウト
   ├─ appspec.yaml ✅ 取得
   ├─ nextjs-taskdef.json ✅ 取得
   └─ go-server-taskdef.json ✅ 取得

2. buildspec.yaml を実行
   ├─ Docker イメージ ビルド＆ECR Push
   └─ (ファイルはそのまま使用)

3. artifacts ブロック
   ├─ appspec.yaml → S3 へアップロード
   ├─ nextjs-taskdef.json → S3 へアップロード
   └─ go-server-taskdef.json → S3 へアップロード
```

### CodePipeline の認識
```
DeployNextJS アクション
├─ build_output から成果物を取得
├─ "appspec.yaml" を探す (✅ 見つかる)
├─ "nextjs-taskdef.json" を探す (✅ 見つかる)
└─ CodeDeploy に渡す
```

## 関連ファイル

**修正されたファイル:**
- `terraform/modules/cicd/main.tf` - Next.js と Go Server の Deploy アクション設定

**関連するローカルファイル:**
- `appspec.yaml` - プロジェクトルート
- `nextjs-taskdef.json` - プロジェクトルート
- `go-server-taskdef.json` - プロジェクトルート

**関連ドキュメント:**
- `docs/changes/2026_04_25_CodeDeployArtifacts_ローカルGit管理へ変更.md` - 概要説明

## 次のステップ

✅ **実施済み:**
1. `build_output::` プリフィックスを削除
2. ローカルファイル参照に統一

⏳ **確認作業:**
1. `terraform plan` で検証
2. CodeBuild テストビルド実行
3. S3 アーティファクト確認
   ```bash
   aws s3 ls s3://{artifact_bucket}/ --recursive
   ```
4. CodeDeploy デプロイメント実行

💡 **補足:**
- `terraform apply` する前に必ず `terraform plan` で確認
- CodePipeline のトリガーで自動実行
- 必要に応じて手動でビルドをトリガー
