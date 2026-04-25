# TaskDefinition JSON に executionRoleArn と taskRoleArn を追加

## 背景

Fargate で `awslogs` ログドライバを使用する場合、TaskDefinition に **executionRoleArn** を指定する必要があります。この ARN が無いと、コンテナが CloudWatch Logs へのログ出力に失敗します。

エラーメッセージ例：
```
Fargate requires task definition to have execution role ARN to support log driver awslogs.
```

## 問題の詳細

### 旧構造
```json
{
  "family": "ecs-sample-nextjs",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecs-sample-nextjs-dev",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  // executionRoleArn がない！
  // taskRoleArn がない！
}
```

**問題:**
- Fargate が awslogs ログドライバを使用するための executionRoleArn が不足
- タスク内でリソースにアクセスするための taskRoleArn が不足
- CodeDeploy がこの JSON を使用してタスク定義を更新する際にエラー発生

### 必要な状態
```json
{
  "family": "ecs-sample-nextjs",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-execution-role-dev",
  "taskRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-role-nextjs-dev",
  "containerDefinitions": [...]
}
```

## 修正内容

### ファイル: `terraform/modules/compute/ecs/main.tf`

#### Next.js TaskDefinition JSON の修正

**変更前:**
```hcl
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.module}/../../../../nextjs-taskdef.json"
  content = jsonencode({
    family                   = aws_ecs_task_definition.nextjs.family
    networkMode              = "awsvpc"
    requiresCompatibilities  = ["FARGATE"]
    cpu                      = tostring(var.nextjs_task_cpu)
    memory                   = tostring(var.nextjs_task_memory)
    containerDefinitions = [...]
  })
}
```

**変更後:**
```hcl
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.module}/../../../../nextjs-taskdef.json"
  content = jsonencode({
    family                   = aws_ecs_task_definition.nextjs.family
    networkMode              = "awsvpc"
    requiresCompatibilities  = ["FARGATE"]
    cpu                      = tostring(var.nextjs_task_cpu)
    memory                   = tostring(var.nextjs_task_memory)
    executionRoleArn         = aws_iam_role.ecs_task_execution_role.arn
    taskRoleArn              = aws_iam_role.ecs_task_role_nextjs.arn
    containerDefinitions = [...]
  })
}
```

#### Go Server TaskDefinition JSON の修正

**変更前:**
```hcl
resource "local_file" "go_server_taskdef_json" {
  filename = "${path.module}/../../../../go-server-taskdef.json"
  content = jsonencode({
    family                   = aws_ecs_task_definition.go_server.family
    networkMode              = "awsvpc"
    requiresCompatibilities  = ["FARGATE"]
    cpu                      = tostring(var.go_server_task_cpu)
    memory                   = tostring(var.go_server_task_memory)
    containerDefinitions = [...]
  })
}
```

**変更後:**
```hcl
resource "local_file" "go_server_taskdef_json" {
  filename = "${path.module}/../../../../go-server-taskdef.json"
  content = jsonencode({
    family                   = aws_ecs_task_definition.go_server.family
    networkMode              = "awsvpc"
    requiresCompatibilities  = ["FARGATE"]
    cpu                      = tostring(var.go_server_task_cpu)
    memory                   = tostring(var.go_server_task_memory)
    executionRoleArn         = aws_iam_role.ecs_task_execution_role.arn
    taskRoleArn              = aws_iam_role.ecs_task_role_go_server.arn
    containerDefinitions = [...]
  })
}
```

## 使用される IAM ロール

### executionRoleArn （共通）
```
aws_iam_role.ecs_task_execution_role.arn
```

**責務:**
- ECR からのイメージ取得
- CloudWatch Logs へのログ出力
- Secrets Manager からのシークレット取得
- KMS による暗号化/復号化

### taskRoleArn （サービスごと）

#### Next.js
```
aws_iam_role.ecs_task_role_nextjs.arn
```

**責務:**
- CloudWatch Logs へのログ出力
- X-Ray へのトレース送信
- CloudWatch Metrics への送信

#### Go Server
```
aws_iam_role.ecs_task_role_go_server.arn
```

**責務:**
- CloudWatch Logs へのログ出力
- X-Ray へのトレース送信
- Secrets Manager からのシークレット取得
- RDS データベース接続
- CloudWatch Metrics への送信
- KMS による復号化

## 効果

✅ TaskDefinition JSON が Fargate/awslogs 要件を満たすようになる  
✅ CodeDeploy がこの JSON を使用してタスク定義を更新する際に、IAM ロール情報が含まれる  
✅ CloudWatch Logs へのログ出力が正常に機能する  
✅ コンテナ内でセキュアに AWS リソースにアクセス可能  
✅ Terraform 検証済み（`terraform validate` 成功）  

## 生成されるファイル例

### nextjs-taskdef.json
```json
{
  "family": "ecs-sample-nextjs",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-execution-role-dev",
  "taskRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-role-nextjs-dev",
  "containerDefinitions": [
    {
      "name": "ecs-sample-nextjs",
      "image": "885545925004.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-nextjs:latest",
      "essential": true,
      "portMappings": [...],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecs-sample-nextjs-dev",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### go-server-taskdef.json
```json
{
  "family": "ecs-sample-go-server",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-execution-role-dev",
  "taskRoleArn": "arn:aws:iam::885545925004:role/ecs-sample-ecs-task-role-go-server-dev",
  "containerDefinitions": [...]
}
```

## 検証

```bash
$ cd terraform && terraform validate
Success! The configuration is valid.
```

## 関連ファイル

- `terraform/modules/compute/ecs/main.tf`: ECS モジュール定義（TaskDefinition JSON 生成 + IAM ロール定義）
- `terraform/modules/compute/ecs/variables.tf`: ECS モジュール変数定義
- `nextjs-taskdef.json`: 生成されるタスク定義（CodeDeploy で使用）
- `go-server-taskdef.json`: 生成されるタスク定義（CodeDeploy で使用）

## 参考資料

- [AWS ECS TaskDefinition - executionRoleArn](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-taskdefinition.html#cfn-ecs-taskdefinition-executionrolearn)
- [AWS Fargate Task Execution Role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-ecs-taskdefinition.html#cfn-ecs-taskdefinition-taskrolearn)
- [CloudWatch Logs for ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_cloudwatch_logs.html)
