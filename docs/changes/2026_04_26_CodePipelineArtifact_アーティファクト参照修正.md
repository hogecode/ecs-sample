# CodePipeline アーティファクト参照修正 - source_output の不正参照を修正

## 概要
CodePipeline の DeployNextJS ステージが、Build ステージの出力を参照すべきところを Source ステージの出力（source_output）を参照していたため、アーティファクト不一致エラーが発生していました。修正により、各デプロイステージが Build ステージの output_artifacts（build_output）を正しく参照するようにしました。

## 🔴 修正前の問題

### エラーメッセージ
```
Artifact named: source_output does not match any of the expected artifacts.
```

### 原因の詳細

#### 1. buildspec.yaml に artifacts セクションがない
```yaml
# ❌ artifacts セクションが存在しない
# Docker イメージビルド＆ECR プッシュだけが実行されていた
```
→ **build_output アーティファクトが実際に生成されていない状況**

#### 2. DeployNextJS ステージが source_output を参照
```hcl
# ❌ 誤り：source_output は GitHub チェックアウト直後のソースコード
action {
  name            = "DeployNextJSAction"
  category        = "Deploy"
  owner           = "AWS"
  provider        = "CodeDeployToECS"
  input_artifacts = ["source_output"]  # ❌ 間違い
  
  configuration = {
    AppSpecTemplateArtifact = "appspec-nextjs.yaml"
    TaskDefinitionTemplateArtifact = "nextjs-taskdef.json"
  }
}
```

### なぜ問題だったのか？

**CodePipeline のアーティファクト フロー：**
```
Source Stage
└─ output: source_output (GitHub リポジトリの内容)
    ├─ appspec-nextjs.yaml ← ローカルファイル（Git管理）
    ├─ nextjs-taskdef.json ← ローカルファイル（Git管理）
    └─ buildspec.yaml

Build Stage
├─ input: source_output
├─ Docker ビルド & ECR プッシュ
├─ artifacts セクション ← ❌ 未定義
└─ output: build_output ← ❌ 実際に生成されない

DeployNextJS Stage
└─ input_artifacts = ["source_output"]  # ← ❌ Build 出力を参照すべき
```

**source_output には以下の内容が含まれます：**
- ソースコードのみ
- appspec-*.yaml ファイルはあるが、Terraform が生成したファイルではない
- アーティファクト名の定義がない

**build_output には以下の内容が含まれるべき：**
- appspec-nextjs.yaml（Terraform テンプレートから生成）
- appspec-go-server.yaml（Terraform テンプレートから生成）
- nextjs-taskdef.json（ローカルファイル）
- go-server-taskdef.json（ローカルファイル）

→ **source_output には named artifact がないため、CodePipeline が照合できず、エラーが発生**

---

## ✅ 修正内容

### 修正 1: buildspec.yaml に artifacts セクション追加

**修正前:**
```yaml
cache:
  paths:
    - '/root/.docker/**/*'

# ========================================
# Environment Variables
# ========================================
```

**修正後:**
```yaml
artifacts:
  files:
    - appspec-nextjs.yaml         # Terraform が生成
    - appspec-go-server.yaml      # Terraform が生成
    - nextjs-taskdef.json         # ローカルファイル
    - go-server-taskdef.json      # ローカルファイル
  name: build_output               # ✅ アーティファクト名を定義

cache:
  paths:
    - '/root/.docker/**/*'

# ========================================
# Environment Variables
# ========================================
```

**効果:**
- CodeBuild が source_output から取得したファイルを build_output アーティファクトとして出力
- S3 アーティファクトストアに `build_output` として保存される
- 次段階の Deploy ステージが `build_output` を参照可能になる

### 修正 2: DeployNextJS ステージの input_artifacts を修正

**修正前:**
```terraform
dynamic "stage" {
  for_each = var.ecs_nextjs_cluster_name != "" && var.ecs_nextjs_service_name != "" ? [1] : []
  content {
    name = "DeployNextJS"

    action {
      name            = "DeployNextJSAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["source_output"]  # ❌ 間違い
      version         = "1"
      run_order       = 1

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
        AppSpecTemplateArtifact = "appspec-nextjs.yaml"
        TaskDefinitionTemplateArtifact = "nextjs-taskdef.json"
      }
    }
  }
}
```

**修正後:**
```terraform
dynamic "stage" {
  for_each = var.ecs_nextjs_cluster_name != "" && var.ecs_nextjs_service_name != "" ? [1] : []
  content {
    name = "DeployNextJS"

    action {
      name            = "DeployNextJSAction"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["build_output"]  # ✅ Build ステージの出力を参照
      version         = "1"
      run_order       = 1

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
        AppSpecTemplateArtifact = "appspec-nextjs.yaml"
        TaskDefinitionTemplateArtifact = "nextjs-taskdef.json"
      }
    }
  }
}
```

**変更点:**
- `input_artifacts = ["source_output"]` → `input_artifacts = ["build_output"]`

---

## 🔄 修正後のパイプライン フロー

```
GitHub リポジトリ
└─ Source Stage
   ├─ output: source_output
   │  ├─ buildspec.yaml
   │  ├─ appspec-nextjs.yaml（Git管理）
   │  ├─ appspec-go-server.yaml（Git管理）
   │  ├─ nextjs-taskdef.json（Git管理）
   │  └─ go-server-taskdef.json（Git管理）
   │
   └─→ Build Stage
      ├─ input: source_output
      ├─ Docker イメージ ビルド & ECR プッシュ
      ├─ artifacts セクション実行 ✅
      │  ├─ appspec-nextjs.yaml（Terraform テンプレートから生成）
      │  ├─ appspec-go-server.yaml（Terraform テンプレートから生成）
      │  ├─ nextjs-taskdef.json（コピー）
      │  └─ go-server-taskdef.json（コピー）
      └─ output: build_output ✅ (S3 に保存)
         │
         ├─→ Scan Stage（並行実行）
         │   ├─ input: source_output
         │   └─ Trivy セキュリティスキャン
         │
         ├─→ DeployNextJS Stage ✅
         │   ├─ input: build_output
         │   ├─ appspec-nextjs.yaml 読み込み
         │   ├─ nextjs-taskdef.json 読み込み
         │   └─ CodeDeploy に渡す
         │
         └─→ DeployGoServer Stage ✅
             ├─ input: build_output
             ├─ appspec-go-server.yaml 読 み込み
             ├─ go-server-taskdef.json 読み込み
             └─ CodeDeploy に渡す
```

---

## 📊 修正の詳細比較

| 項目 | 修正前 | 修正後 |
|-----|--------|--------|
| **buildspec.yaml artifacts** | ❌ なし | ✅ 追加 |
| **build_output 生成** | ❌ 未定義 | ✅ 定義済み |
| **DeployNextJS input** | ❌ source_output | ✅ build_output |
| **DeployGoServer input** | ✅ build_output | ✅ build_output（変更なし）|
| **Scan ステージ input** | ✅ source_output | ✅ source_output（変更なし）|
| **エラー発生** | ❌ はい | ✅ 解決 |

---

## 💡 アーティファクト参照の考え方

### **source_output を参照すべき場面：**
- Source ステージ直後のステージ
- ソースコードのみが必要な場合（例：セキュリティスキャン）
- リポジトリから取得した Git 管理ファイルを使用する場合

### **build_output を参照すべき場面：**
- Build ステージ後のステージ（Deploy など）
- ビルド成果物が必要な場合
- Terraform で生成されたファイルが必要な場合
- CodeBuild の artifacts セクションで出力されたファイルを参照する場合

### **重要：各ステージのアーティファクト定義**

```
Source Stage
└─ output_artifacts = ["source_output"]  ← ロックされている（固定）

Build Stage
├─ input_artifacts  = ["source_output"]  ← Source から受け取る
└─ output_artifacts = ["build_output"]   ← buildspec.yaml で定義

Deploy Stage（Next.js）
├─ input_artifacts = ["build_output"]    ← Build から受け取る
└─ output_artifacts = なし

Deploy Stage（Go Server）
├─ input_artifacts = ["build_output"]    ← Build から受け取る
└─ output_artifacts = なし
```

---

## 🎯 テスト確認項目

修正後の動作確認：

### 1. CodeBuild ビルドログ確認
```bash
# CloudWatch Logs で以下を確認
# - Docker イメージ ビルド成功
# - ECR プッシュ成功
# - artifacts セクション実行
# - appspec-*.yaml と taskdef.json が処理されている
```

### 2. S3 アーティファクト確認
```bash
# build_output アーティファクトが S3 に保存されたか確認
aws s3 ls s3://{artifact_bucket}/ --recursive | grep build_output

# 以下ファイルが存在すること
# - appspec-nextjs.yaml
# - appspec-go-server.yaml
# - nextjs-taskdef.json
# - go-server-taskdef.json
```

### 3. CodePipeline 実行確認
```bash
# パイプライン全体が成功するか確認
# - Build ステージ完了
# - Scan ステージ完了（並行）
# - DeployNextJS ステージ完了
# - DeployGoServer ステージ完了

# CodeDeploy デプロイメント成功を確認
aws deploy describe-deployment --deployment-id d-XXXXXXXXXXXXX
```

---

## 関連ファイル

**修正されたファイル:**
- `buildspec.yaml` - artifacts セクション追加
- `terraform/modules/cicd/main.tf` - DeployNextJS input_artifacts 修正

**関連する生成ファイル（Terraform）:**
- `terraform/appspec-nextjs.yaml` - local_file で生成
- `terraform/appspec-go-server.yaml` - local_file で生成

**関連するローカルファイル（Git 管理）:**
- `terraform/nextjs-taskdef.json`
- `terraform/go-server-taskdef.json`

---

## 次のステップ

✅ **実施済み:**
1. buildspec.yaml に artifacts セクションを追加
2. DeployNextJS ステージの input_artifacts を修正
3. ドキュメント化

⏳ **確認作業:**
1. `terraform plan` で検証
2. CodeBuild テストビルド実行
3. S3 アーティファクト確認
4. CodePipeline 実行確認
5. CodeDeploy デプロイメント成功確認

💡 **オプショナル:**
- CI/CD パイプライン図を更新
- 関連ドキュメント（docs/CI_CD.md など）を更新

---

## 参考資料

- [AWS CodePipeline - アーティファクトの操作](https://docs.aws.amazon.com/ja_jp/codepipeline/latest/userguide/working-with-artifacts.html)
- [AWS CodeBuild - buildspec リファレンス](https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/build-spec-ref.html#artifacts)
- [AWS CodeDeploy - AppSpec ファイルリファレンス](https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/application-specification-files.html)
