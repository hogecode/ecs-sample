# CodeDeploy TaskDefinitionTemplateArtifact 形式修正

## 概要
terraform/modules/cicd/main.tf 内の CodePipeline Deploy アクション設定で、参照する TaskDefinitionTemplateArtifact の形式が正しくなかったため、修正を行いました。

## 🔴 修正前の問題

### Terraform 設定（cicd/main.tf）
```terraform
# Next.js deployment
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  TaskDefinitionTemplateArtifact = "build_output::nextjs_taskdef.json" # ❌
}

# Go Server deployment
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  TaskDefinitionTemplateArtifact = "build_output::go_server_taskdef.json" # ❌
}
```

### buildspec.yaml で実際に生成されるもの
```yaml
# imagedefinitions.json のみ生成される
printf '[
  {"name":"nextjs-container","imageUri":"%s"},
  {"name":"go-server-container","imageUri":"%s"}
]' $NEXTJS_REPO_URI:$IMAGE_TAG $GO_SERVER_REPO_URI:$IMAGE_TAG > imagedefinitions.json
```

### 問題点
- ❌ `nextjs_taskdef.json` は生成されていない
- ❌ `go_server_taskdef.json` は生成されていない
- ✅ `imagedefinitions.json` は生成されている
- ❌ `appspec.yaml` が必要だが生成されていない

## ✅ 修正内容

### terraform/modules/cicd/main.tf

#### Next.js Deployment Action
**修正前:**
```terraform
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  TaskDefinitionTemplateArtifact = "build_output::nextjs_taskdef.json"
}
```

**修正後:**
```terraform
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.nextjs_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"
  TaskDefinitionTemplateArtifact = "build_output::nextjs-taskdef.json"
}
```

#### Go Server Deployment Action
**修正前:**
```terraform
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  TaskDefinitionTemplateArtifact = "build_output::go_server_taskdef.json"
}
```

**修正後:**
```terraform
configuration = {
  ApplicationName     = aws_codedeploy_app.app.name
  DeploymentGroupName = aws_codedeploy_deployment_group.go_deployment_group[0].deployment_group_name
  AppSpecTemplateArtifact = "build_output::appspec.yaml"
  TaskDefinitionTemplateArtifact = "build_output::go-server-taskdef.json"
}
```

## 📊 変更点サマリー

| 項目 | 修正前 | 修正後 |
|-----|--------|--------|
| Next.js TaskDef | `nextjs_taskdef.json` | `nextjs-taskdef.json` |
| Go Server TaskDef | `go_server_taskdef.json` | `go-server-taskdef.json` |
| AppSpec テンプレート | なし | `appspec.yaml` |

## ⚠️ 次のステップ（必須）

### buildspec.yaml の更新が必要

buildspec.yaml で以下のファイルを生成する必要があります：

1. **appspec.yaml**
   - CodeDeploy の設定ファイル
   - Blue/Green デプロイメント時の lifecycle hooks を定義

2. **nextjs-taskdef.json**
   - Next.js のタスク定義テンプレート
   - プレースホルダ `<IMAGE1_NAME>` を使用して、CodePipeline が実際のイメージ URI に置換

3. **go-server-taskdef.json**
   - Go Server のタスク定義テンプレート
   - プレースホルダ `<IMAGE1_NAME>` を使用して、CodePipeline が実際のイメージ URI に置換

### buildspec.yaml の修正内容（計画）

```yaml
post_build:
  commands:
    # ... 既存の docker push コマンド ...
    
    # appspec.yaml を生成
    - |
      cat > appspec.yaml << 'EOF'
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
      EOF
    
    # nextjs-taskdef.json を生成
    - |
      cat > nextjs-taskdef.json << 'EOF'
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
            "portMappings": [
              {
                "containerPort": 3000,
                "protocol": "tcp"
              }
            ]
          }
        ]
      }
      EOF
    
    # go-server-taskdef.json を生成
    - |
      cat > go-server-taskdef.json << 'EOF'
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
            "portMappings": [
              {
                "containerPort": 8080,
                "protocol": "tcp"
              }
            ]
          }
        ]
      }
      EOF
```

## 関連ファイル

### 修正ファイル
- `terraform/modules/cicd/main.tf` - Deploy アクション設定を更新

### 要更新ファイル（次のステップ）
- `buildspec.yaml` - appspec.yaml と taskdef.json の生成を追加

## 参考資料

- AWS CodeDeploy ECS デプロイメント: https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/service-role-ecs.html
- appspec.yaml リファレンス: https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/application-specification-files.html
- ECS タスク定義: https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/task_definitions.html
