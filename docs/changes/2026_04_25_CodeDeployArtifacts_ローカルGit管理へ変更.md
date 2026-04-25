# CodeDeploy アーティファクト - ローカルGit管理へ変更

## 概要
buildspec.yaml で cat EOF により動的に生成していた CodeDeploy 用のアーティファクトファイルを、プロジェクトのルートに配置して Git で管理するに変更しました。

## 📋 修正内容

### 修正前
buildspec.yaml の post_build フェーズで動的に3つのファイルを生成：

```yaml
post_build:
  commands:
    # ... docker push コマンド ...
    
    # appspec.yaml を cat EOF で生成
    - |
      cat > appspec.yaml << 'EOF'
      version: 0.0
      ...
      EOF
    
    # nextjs-taskdef.json を cat EOF で生成
    - |
      cat > nextjs-taskdef.json << 'EOF'
      {
        ...
      }
      EOF
    
    # go-server-taskdef.json を cat EOF で生成
    - |
      cat > go-server-taskdef.json << 'EOF'
      {
        ...
      }
      EOF
```

**問題点：**
- ❌ buildspec.yaml が非常に冗長で読みづらい
- ❌ ファイルの修正が buildspec.yaml を編集する必要がある
- ❌ Git 履歴が buildspec.yaml の一部として管理される
- ❌ 複数環境での設定差があった場合、対応が複雑

### 修正後
プロジェクトのルートに3つのファイルを配置して Git で管理：

```
project-root/
├── appspec.yaml              ✅ 新規作成
├── nextjs-taskdef.json       ✅ 新規作成
├── go-server-taskdef.json    ✅ 新規作成
├── buildspec.yaml            ✅ 簡潔に
├── terraform/
└── docs/
```

buildspec.yaml は単純に参照：

```yaml
artifacts:
  files:
    - appspec.yaml              # ✅ ローカルファイル参照
    - nextjs-taskdef.json       # ✅ ローカルファイル参照
    - go-server-taskdef.json    # ✅ ローカルファイル参照
  name: BuildArtifact
```

**利点：**
- ✅ buildspec.yaml がシンプルで読みやすい
- ✅ 各ファイルを独立して修正・管理できる
- ✅ Git 履歴で個別にファイル変更を追跡
- ✅ IDE のシンタックスハイライト・検証が機能
- ✅ 複数環境での設定差を branches で管理可能

## 📁 新規作成ファイル

### 1. appspec.yaml
**場所:** プロジェクトルート  
**役割:** CodeDeploy ECS Blue/Green デプロイメント設定

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "<TASK_DEFINITION>"
        LoadBalancerInfo:
          ContainerName: "<CONTAINER_NAME>"
          ContainerPort: <CONTAINER_PORT>
        PlatformVersion: "LATEST"
        NetworkConfiguration:
          AwsVpcConfiguration:
            AssignPublicIp: DISABLED
            Subnets:
              - "<SUBNET_1>"
              - "<SUBNET_2>"
            SecurityGroups:
              - "<SECURITY_GROUP>"
Hooks:
  - BeforeAllowTraffic: "CodeDeployHook_BeforeAllowTraffic"
  - AfterAllowTraffic: "CodeDeployHook_AfterAllowTraffic"
```

### 2. nextjs-taskdef.json
**場所:** プロジェクトルート  
**役割:** Next.js ECS タスク定義テンプレート

```json
{
  "family": "ecs-sample-nextjs",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "nextjs-container",
      "image": "<IMAGE1_NAME>",
      "portMappings": [...],
      "essential": true,
      "logConfiguration": {...}
    }
  ]
}
```

### 3. go-server-taskdef.json
**場所:** プロジェクトルート  
**役割:** Go Server ECS タスク定義テンプレート

```json
{
  "family": "ecs-sample-go-server",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "go-server-container",
      "image": "<IMAGE1_NAME>",
      "portMappings": [...],
      "essential": true,
      "logConfiguration": {...}
    }
  ]
}
```

## 🔄 デプロイフロー（変更後）

```
1. Git リポジトリ
   ├─ appspec.yaml ✅
   ├─ nextjs-taskdef.json ✅
   └─ go-server-taskdef.json ✅
        ↓
2. CodeBuild (buildspec.yaml)
   ├─ ソースコードチェックアウト（↑ファイル取得）
   ├─ Docker イメージ ビルド＆ECR Push
   └─ アーティファクト出力
        ↓ (ローカルファイルをそのまま出力)
3. S3 アーティファクトストア
   ├─ appspec.yaml
   ├─ nextjs-taskdef.json
   └─ go-server-taskdef.json
        ↓
4. CodePipeline Deploy Stage
   └─ CodeDeploy に渡す
        ↓
5. CodeDeploy Blue/Green
   └─ デプロイメント実行
```

## 💡 プレースホルダ置換

### `<IMAGE1_NAME>` の置換タイミング

```
buildspec.yaml で生成 ❌（修正前）
  → 動的に生成されるため、変更が複雑

ローカルファイルで定義 ✅（修正後）
  → CodePipeline が自動で置換
  → 実行時に正しいイメージ URI に置換
  → 置換形式：{account_id}.dkr.ecr.{region}.amazonaws.com/{repo}:{tag}
```

## 🔍 Git 管理の利点

### ファイル修正の例

**修正前：** buildspec.yaml を編集
```bash
# buildspec.yaml の大きなファイルを編集
git diff buildspec.yaml  # 全体が表示される
```

**修正後：** 対象ファイルのみ編集
```bash
# 個別ファイルを修正
git diff nextjs-taskdef.json  # 該当部分のみ表示
git diff appspec.yaml         # 該当部分のみ表示
```

### 環境別の設定
```bash
# dev ブランチ
git checkout develop
cat appspec.yaml  # dev 環境用

# prod ブランチ
git checkout main
cat appspec.yaml  # prod 環境用
```

## ⚠️ 重要な注意事項

### CodeBuild で参照
CodeBuild は Git チェックアウト時にこれらのファイルを自動取得：

1. **Source → artifacts** に変更なし
2. `appspec.yaml` → S3 にアップロード
3. `nextjs-taskdef.json` → S3 にアップロード
4. `go-server-taskdef.json` → S3 にアップロード

### 修正時の確認
```bash
# ファイルが正しく作成されたか確認
ls -la *.yaml *.json

# JSON の妥当性確認
jq . nextjs-taskdef.json
jq . go-server-taskdef.json

# YAML の妥当性確認
yamllint appspec.yaml
```

## 📝 Git コミット例

```bash
git add appspec.yaml nextjs-taskdef.json go-server-taskdef.json buildspec.yaml
git commit -m "chore: CodeDeploy artifacts をローカルGit管理へ変更"
```

### コミットメッセージ内容
- appspec.yaml の動的生成をローカルファイル参照に変更
- buildspec.yaml から cat EOF コマンドを削除
- より読みやすく管理しやすいファイル構成に

## 🎯 修正の効果

| 項目 | 修正前 | 修正後 |
|-----|--------|--------|
| **ファイル場所** | buildspec.yaml 内 | ローカル（Git管理） |
| **buildspec.yaml の行数** | ~150行 | ~70行 |
| **ファイル修正** | buildspec.yaml 編集 | 対象ファイルのみ編集 |
| **Git 履歴** | buildspec.yaml に含まれる | 個別に追跡 |
| **IDE サポート** | △ YAML内JSON（辛い） | ✅ ネイティブサポート |
| **環境別設定** | △ ブランチ全体で管理 | ✅ ファイル単位で管理 |

## 関連ファイル

**修正されたファイル:**
- `buildspec.yaml` - cat EOF セクションを削除

**新規作成ファイル:**
- `appspec.yaml` - プロジェクトルート
- `nextjs-taskdef.json` - プロジェクトルート
- `go-server-taskdef.json` - プロジェクトルート

**Terraform 設定（変更なし）:**
- `terraform/modules/cicd/main.tf` - TaskDefinitionTemplateArtifact 参照は同じ

## 次のステップ

✅ **実施済み:**
1. appspec.yaml, taskdef.json をローカルに作成
2. buildspec.yaml から動的生成コマンドを削除
3. Git で管理開始

⏳ **確認作業:**
1. `terraform plan` で検証
2. CodeBuild テストビルド実行
3. S3 アーティファクト確認
4. CodeDeploy デプロイメント実行

💡 **オプショナル:**
- yamllint / jq で構文検証の CI/CD 追加
- 環境別の appspec.yaml テンプレート作成
