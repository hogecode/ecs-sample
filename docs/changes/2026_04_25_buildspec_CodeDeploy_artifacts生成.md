# buildspec.yaml - CodeDeploy artifacts 生成機能追加

## 概要
buildspec.yaml を更新して、CodeDeploy と CodePipeline による Blue/Green デプロイメントに必要な3つのアーティファクトファイルを生成するようにしました。

## 📝 修正内容

### 修正前の問題
```yaml
artifacts:
  files:
    - imagedefinitions.json  # ❌ ECS の古い形式（非推奨）
```

- `imagedefinitions.json` のみが出力されていた
- CodeDeploy には `appspec.yaml` が必須
- タスク定義テンプレートが生成されていない

### 修正後
```yaml
artifacts:
  files:
    - appspec.yaml              # ✅ CodeDeploy の設定ファイル
    - nextjs-taskdef.json       # ✅ Next.js タスク定義テンプレート
    - go-server-taskdef.json    # ✅ Go Server タスク定義テンプレート
```

## 🔧 生成されるファイル詳細

### 1. appspec.yaml
**役割:** CodeDeploy の ECS デプロイメント設定

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

**主な役割:**
- Blue/Green デプロイメントの設定
- ロードバランサー統合
- Lifecycle hooks（カスタムコードを実行するタイミング）
- プレースホルダ置換（CodePipeline が実行時に値を設定）

### 2. nextjs-taskdef.json
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
      "image": "<IMAGE1_NAME>",  // CodePipeline が実際のイメージ URI に置換
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecs-sample-nextjs",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

**主な役割:**
- Next.js コンテナの起動設定
- `<IMAGE1_NAME>` プレースホルダを CodePipeline が置換
- CloudWatch Logs 統合

### 3. go-server-taskdef.json
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
      "image": "<IMAGE1_NAME>",  // CodePipeline が実際のイメージ URI に置換
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecs-sample-go-server",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

**主な役割:**
- Go Server コンテナの起動設定
- `<IMAGE1_NAME>` プレースホルダを CodePipeline が置換
- CloudWatch Logs 統合

## 📊 デプロイフロー

```
1. CodeBuild (buildspec.yaml 実行)
   ├─ Docker イメージをビルド＆ECR にプッシュ
   ├─ appspec.yaml を生成
   ├─ nextjs-taskdef.json を生成
   └─ go-server-taskdef.json を生成

2. S3 アーティファクトストア
   └─ 3つのファイルを保存

3. CodePipeline - Deploy Stage
   ├─ build_output から appspec.yaml を読み込み
   ├─ build_output から nextjs-taskdef.json を読み込み
   └─ CodeDeploy に渡す

4. CodeDeploy - Blue/Green デプロイ
   ├─ Green タスク定義を作成
   ├─ Green タスクをスタート
   ├─ ヘルスチェック実行
   ├─ トラフィック切り替え
   └─ Blue タスク停止

5. ECS Service
   └─ Green タスクが本番環境で実行
```

## ⚠️ 重要な注意事項

### プレースホルダ置換
- `<IMAGE1_NAME>` は CodePipeline が実際のイメージ URI に置換
- 形式: `{account_id}.dkr.ecr.{region}.amazonaws.com/{repository}:{tag}`
- 例: `885545925004.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-nextjs:a1b2c3d`

### Terraform 設定との同期
以下の Terraform 設定と整合性を取っています：

```terraform
# terraform/modules/cicd/main.tf
configuration = {
  ApplicationName = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"
  TaskDefinitionTemplateArtifact = "build_output::nextjs-taskdef.json"
}
```

## 🔍 動作確認ポイント

### ローカル検証
```bash
# buildspec.yaml の構文確認
cd /path/to/project
cat buildspec.yaml | head -60  # 前半確認

# アーティファクトセクション確認
tail -20 buildspec.yaml  # アーティファクト出力
```

### CodeBuild ビルドログ確認
1. AWS CodePipeline コンソール → パイプライン選択
2. Build ステージ → CodeBuild プロジェクト → ビルドID クリック
3. ログを確認
   - `appspec.yaml generated` ✅
   - `nextjs-taskdef.json generated` ✅
   - `go-server-taskdef.json generated` ✅

### S3 アーティファクト確認
```bash
# 生成されたファイル確認
aws s3 ls s3://{artifact_bucket_name}/codepipeline/{pipeline_name}/ \
  --recursive | grep -E "(appspec|taskdef)"
```

## 関連ドキュメント

- Terraform 修正: `docs/changes/2026_04_25_CodeDeployTaskDefinitionArtifact形式修正.md`
- AWS CodeDeploy ECS: https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/application-revisions-ecs.html
- appspec.yaml リファレンス: https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/application-specification-files.html
- ECS タスク定義: https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definitions.html

## 次のステップ

✅ **実施済み:**
- Terraform terraform/modules/cicd/main.tf を修正
- buildspec.yaml に appspec.yaml と taskdef.json 生成処理を追加

⏳ **必要な確認:**
1. CodeBuild ビルド実行
2. S3 アーティファクト確認
3. CodeDeploy デプロイメント実行
4. Blue/Green 切り替え動作確認

💡 **オプショナル:**
- appspec.yaml の Lifecycle hooks に実装
  - `BeforeAllowTraffic`: ヘルスチェック
  - `AfterAllowTraffic`: スモークテスト
