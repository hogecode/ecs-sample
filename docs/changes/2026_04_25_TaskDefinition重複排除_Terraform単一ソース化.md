# Task Definition 重複排除 - Terraform を唯一のソースに統一

## 概要
Terraform の `aws_ecs_task_definition` と CodeDeploy 用の JSON ファイルが重複していた問題を解決しました。Terraform を唯一のソース（Single Source of Truth）とし、`local_file` リソースで自動生成するようにしました。

## 🔴 修正前の問題

### 重複管理の課題
```
terraform/modules/compute/ecs/main.tf
├─ aws_ecs_task_definition.nextjs (Terraform)
└─ aws_ecs_task_definition.go_server (Terraform)

nextjs-taskdef.json (CodeDeploy用)
└─ 手動管理の JSON ファイル ❌ 重複

go-server-taskdef.json (CodeDeploy用)
└─ 手動管理の JSON ファイル ❌ 重複
```

**問題点：**
- ❌ 同じ情報を2つの場所で管理
- ❌ 変更時に両方を修正する必要がある
- ❌ Single Source of Truth がない
- ❌ Git では2つの異なる履歴が生成される
- ❌ 同期ズレのリスク

## ✅ 修正内容

### terraform/modules/compute/ecs/main.tf に local_file を追加

```terraform
# Next.js Task Definition JSON を自動生成
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.root}/nextjs-taskdef.json"
  content = jsonencode({
    family                   = aws_ecs_task_definition.nextjs.family
    networkMode              = "awsvpc"
    requiresCompatibilities  = ["FARGATE"]
    cpu                      = tostring(var.nextjs_task_cpu)
    memory                   = tostring(var.nextjs_task_memory)
    containerDefinitions = [
      {
        name                 = "${var.project_name}-nextjs"
        image                = "<IMAGE1_NAME>"           # CodePipeline が置換
        essential            = true
        portMappings         = [...]
        logConfiguration     = {...}
      }
    ]
  })
}

# Go Server Task Definition JSON を自動生成
resource "local_file" "go_server_taskdef_json" {
  filename = "${path.root}/go-server-taskdef.json"
  content = jsonencode({
    # 同じ構造で自動生成
  })
}
```

**利点：**
- ✅ Terraform が唯一のソース
- ✅ `terraform apply` で JSON が自動生成される
- ✅ 変更は Terraform のみで OK
- ✅ 同期ズレが発生しない
- ✅ Git で追跡可能

## 📊 修正の効果

| 項目 | 修正前 | 修正後 |
|-----|--------|--------|
| **ソース** | 手動 JSON | Terraform 🚀 |
| **管理箇所** | 2箇所（重複） | 1箇所 ✅ |
| **生成方法** | 手動編集 | `terraform apply` 時に自動 ✅ |
| **変更手順** | JSON 編集 + Terraform編集 | Terraform のみ ✅ |
| **同期ズレ** | 発生する可能性 | なし ✅ |

## 🔄 デプロイフロー（修正後）

```
1. terraform apply 実行
   ├─ aws_ecs_task_definition.nextjs を作成
   ├─ aws_ecs_task_definition.go_server を作成
   ├─ local_file.nextjs_taskdef_json を生成 ✅
   └─ local_file.go_server_taskdef_json を生成 ✅
        ↓
2. nextjs-taskdef.json / go-server-taskdef.json が生成される
   ├─ Terraform から自動生成
   └─ プロジェクトルートに配置
        ↓
3. Git で管理
   ├─ buildspec.yaml が参照
   └─ CodePipeline が Deploy Stage で使用
        ↓
4. CodeDeploy Blue/Green
   └─ デプロイメント実行
```

## 💡 Single Source of Truth の利点

### 修正前（重複管理）
```bash
# 容量を増やしたい場合
# 1. terraform/modules/compute/ecs/main.tf を編集
vi terraform/modules/compute/ecs/main.tf
# cpu = 256 → cpu = 512

# 2. nextjs-taskdef.json も編集
vi nextjs-taskdef.json
# "cpu": "256" → "cpu": "512"

# 3. 両方を git add して commit
# ❌ 2つの変更が1つの概念なのに2つのコミットになる可能性
```

### 修正後（唯一のソース）
```bash
# 容量を増やしたい場合
# 1. terraform/modules/compute/ecs/main.tf のみ編集
vi terraform/modules/compute/ecs/main.tf
# cpu = 256 → cpu = 512

# 2. terraform apply で自動生成
terraform apply

# 3. 1つの変更として記録される
# ✅ Single Source of Truth を実現
```

## ✨ 実装のポイント

### `local_file` リソースの動作
```terraform
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.root}/nextjs-taskdef.json"
  # path.root = Terraform ルートディレクトリ（プロジェクトルート）
  
  content = jsonencode({
    # Terraform の値から JSON を生成
    family  = aws_ecs_task_definition.nextjs.family
    cpu     = tostring(var.nextjs_task_cpu)  # 文字列に変換
    # ...
  })
}
```

**実行フロー：**
```
terraform apply
  ↓
local_file リソース実行
  ├─ nextjs-taskdef.json を生成
  └─ go-server-taskdef.json を生成
       ↓ (既存ファイルを上書き)
Git の tracked file として更新
       ↓
buildspec.yaml が参照
       ↓
S3 アーティファクト → CodeDeploy
```

## 🎯 JSON ファイルの更新タイミング

| イベント | 動作 |
|---------|------|
| `terraform apply` | JSON ファイル自動生成 |
| `terraform plan` | JSON の差分が表示されない（ローカル生成のため） |
| `terraform destroy` | JSON ファイルは削除されない（安全性のため） |
| Git commit | JSON ファイルも commit される |

## ⚠️ 重要な注意事項

### JSON の <IMAGE1_NAME> プレースホルダ
```json
{
  "containerDefinitions": [
    {
      "image": "<IMAGE1_NAME>"  // CodePipeline が ECR イメージ URI に置換
    }
  ]
}
```

- Terraform では動的値を入れられない（ECR イメージ URI は実行時に決定）
- プレースホルダ `<IMAGE1_NAME>` で固定
- CodePipeline が実行時に置換

### .gitignore の確認（必要に応じて）
```bash
# JSON ファイルは .gitignore に含まれていないことを確認
grep -E "taskdef.json|appspec.yaml" .gitignore

# ない場合は Git で管理される ✅
```

## 🔍 動作確認

### Terraform 実行後の確認
```bash
# JSON ファイルが生成されたか確認
ls -la *.taskdef.json

# 内容を確認
cat nextjs-taskdef.json | jq .

# Git の状態確認
git status
# nextjs-taskdef.json と go-server-taskdef.json が
# Changes to be committed に表示される
```

### JSON の妥当性確認
```bash
# JSON の構文チェック
jq . nextjs-taskdef.json > /dev/null && echo "OK"

# Terraform 変更後、JSON が更新されたか確認
terraform apply
git diff nextjs-taskdef.json
```

## 関連ファイル

**修正されたファイル:**
- `terraform/modules/compute/ecs/main.tf` - `local_file` リソースを追加

**管理対象ファイル:**
- `nextjs-taskdef.json` - Terraform から自動生成
- `go-server-taskdef.json` - Terraform から自動生成
- `appspec.yaml` - 別途管理

**関連するリソース:**
- `aws_ecs_task_definition.nextjs` - Terraform で管理（ECS デプロイ用）
- `aws_ecs_task_definition.go_server` - Terraform で管理（ECS デプロイ用）

## 次のステップ

✅ **実施済み:**
1. `local_file` リソースを追加
2. Terraform から JSON を自動生成するよう実装
3. Single Source of Truth を実現

⏳ **確認作業:**
1. `terraform plan` で出力内容確認
2. `terraform apply` で JSON ファイル生成確認
3. `git status` で JSON ファイルの更新確認
4. CodeBuild ビルド実行
5. CodeDeploy デプロイメント実行

💡 **今後の管理方法:**
- Terraform の `aws_ecs_task_definition` のみ修正
- JSON ファイルは手動編集不要（自動生成）
- `terraform apply` で常に同期状態を維持
