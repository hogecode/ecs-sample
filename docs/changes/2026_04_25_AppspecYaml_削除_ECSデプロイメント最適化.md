# appspec.yaml 削除 - ECS デプロイメント最適化

## 概要
ECS Fargate デプロイメントでは appspec.yaml が不要であることが判明したため、このファイルを削除し、プロジェクト構成を最適化しました。

## 削除の理由

### ECS Fargate デプロイメントの仕様
ECS Fargate へのデプロイメントは、以下のアプローチを使用します：

1. **buildspec.yaml**
   - Docker イメージを ECR にプッシュ
   - `imagedefinitions.json` を動的に生成
   - デプロイメント成果物として出力

2. **imagedefinitions.json**
   ```json
   [
     {"name":"nextjs-container","imageUri":"..."},
     {"name":"go-server-container","imageUri":"..."}
   ]
   ```
   - CodePipeline の Deploy ステージで使用
   - ECS タスク定義を更新するのに使用

3. **ECS タスク定義**
   - Terraform で管理（terraform/modules/compute/ecs/）
   - コンテナの詳細設定を定義

### appspec.yaml が使用されないケース
```
EC2 インスタンスデプロイメント → appspec.yaml が必須
ECS デプロイメント          → appspec.yaml は不要
```

## 削除内容

**削除したファイル:**
- `appspec.yaml` （プロジェクトルート）

## 現在のデプロイメントフロー

```
GitHub Code Push
    ↓
Source Stage (CodePipeline)
    ↓
Build Stage (CodeBuild)
  - buildspec.yaml を実行
  - Docker イメージをビルド → ECR にプッシュ
  - imagedefinitions.json を生成
    ↓
Scan Stage (CodeBuild)
  - buildspec-scan.yaml を実行
  - セキュリティスキャン
    ↓
[Approval Stage] (本番環境のみ)
    ↓
DeployNextJS Stage (CodeDeploy)
  - imagedefinitions.json を使用
  - Next.js サービスを更新
    ↓
DeployGoServer Stage (CodeDeploy)
  - imagedefinitions.json を使用
  - Go Server サービスを更新
```

## 管理対象ファイル

### 継続して使用
- ✅ `buildspec.yaml` - Docker イメージビルド
- ✅ `buildspec-scan.yaml` - セキュリティスキャン
- ✅ `terraform/modules/compute/ecs/` - タスク定義
- ✅ `imagedefinitions.json` - CodeBuild の出力成果物

### 削除済み
- ❌ `appspec.yaml` - ECS では不要

## メリット

1. **不要なファイルの削除**
   - プロジェクト構成がシンプルに

2. **混乱の排除**
   - EC2 用の設定が ECS で使用されないことを明確化

3. **保守性の向上**
   - デプロイメント設定の一元化（buildspec.yaml と ECS タスク定義）

## 注意事項

### ECS タスク定義の確認
`imagedefinitions.json` で参照されるコンテナ名は、ECS タスク定義と一致している必要があります：

**buildspec.yaml の出力:**
```json
[
  {"name":"nextjs-container","imageUri":"..."},
  {"name":"go-server-container","imageUri":"..."}
]
```

**ECS タスク定義の container_definitions:**
```hcl
container_definitions = jsonencode([
  {
    name  = "nextjs-container"
    image = "..."
    ...
  },
  {
    name  = "go-server-container"
    image = "..."
    ...
  }
])
```

⚠️ **重要**: `name` フィールドが一致していることを確認してください。

## 関連ドキュメント
- [CodeBuild buildspec.yaml](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
- [ECS デプロイメント](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-steps-ecs.html)
- [imagedefinitions.json フォーマット](https://docs.aws.amazon.com/codedeploy/latest/userguide/app-spec-ref-ecs.html)
