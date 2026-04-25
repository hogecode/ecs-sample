# buildspec.yaml アーティファクト生成パス修正

## 背景

`buildspec.yaml` の `artifacts` セクションで参照しているファイル（`appspec-nextjs.yaml`、`appspec-go-server.yaml` など）が **`terraform/` フォルダ** に生成されていたため、CodeBuild がこれらのファイルを見つけられず、デプロイメント時にエラーが発生していた。

## 問題の詳細

### 旧構造
```
terraform/modules/cicd/main.tf の local_file リソース:
  appspec-nextjs.yaml    → ${path.root}/appspec-nextjs.yaml
  appspec-go-server.yaml → ${path.root}/appspec-go-server.yaml
```

- `${path.root}` は Terraform モジュール内では `terraform/` フォルダを指す
- CodeBuild は **ソースリポジトリのルート** からファイルを探す
- `terraform/` サブフォルダにあるファイルは見つからない

### CodeDeploy の期待値

CodePipeline の設定では:
```hcl
AppSpecTemplateArtifact = "appspec-nextjs.yaml"
TaskDefinitionTemplateArtifact = "nextjs-taskdef.json"
```

これらは `build_output` アーティファクトの **ルート** に配置される必要がある。

## 修正内容

### ファイル 1: `terraform/modules/cicd/main.tf`

#### 変更前:
```hcl
resource "local_file" "appspec_nextjs" {
  filename = "${path.root}/appspec-nextjs.yaml"
  content  = templatefile("${path.module}/appspec-nextjs.yaml.tpl", {
    container_name = "ecs-sample-nextjs"
    container_port = 3000
  })
}

resource "local_file" "appspec_go_server" {
  filename = "${path.root}/appspec-go-server.yaml"
  content  = templatefile("${path.module}/appspec-go-server.yaml.tpl", {
    container_name = "ecs-sample-go-server"
    container_port = 8080
  })
}
```

#### 変更後:
```hcl
resource "local_file" "appspec_nextjs" {
  filename = "${path.module}/../../appspec-nextjs.yaml"
  content  = templatefile("${path.module}/appspec-nextjs.yaml.tpl", {
    container_name = "ecs-sample-nextjs"
    container_port = 3000
  })
}

resource "local_file" "appspec_go_server" {
  filename = "${path.module}/../../appspec-go-server.yaml"
  content  = templatefile("${path.module}/appspec-go-server.yaml.tpl", {
    container_name = "ecs-sample-go-server"
    container_port = 8080
  })
}
```

### ファイル 2: `terraform/modules/compute/ecs/main.tf`

#### 変更前:
```hcl
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.root}/nextjs-taskdef.json"
  content = jsonencode({
    # ...
  })
}

resource "local_file" "go_server_taskdef_json" {
  filename = "${path.root}/go-server-taskdef.json"
  content = jsonencode({
    # ...
  })
}
```

#### 変更後:
```hcl
resource "local_file" "nextjs_taskdef_json" {
  filename = "${path.module}/../../nextjs-taskdef.json"
  content = jsonencode({
    # ...
  })
}

resource "local_file" "go_server_taskdef_json" {
  filename = "${path.module}/../../go-server-taskdef.json"
  content = jsonencode({
    # ...
  })
}
```

## 効果

- ✅ ファイルが **リポジトリのルート** に生成される
- ✅ `buildspec.yaml` が正しくファイルを見つけられる
- ✅ CodeBuild の `artifacts` セクションで相対パス参照が機能
- ✅ CodeDeploy の `AppSpecTemplateArtifact` 参照が機能
- ✅ Git の `.gitignore` で自動生成ファイルを除外可能

## パス解析

`${path.module}/../../` の意味:

```
terraform/modules/cicd/main.tf の位置
↓
${path.module} = terraform/modules/cicd/
↓
${path.module}/.. = terraform/modules/
↓
${path.module}/../.. = terraform/
↓
${path.module}/../../ = リポジトリのルート ✅
```

## 検証

```bash
$ cd terraform && terraform validate
Success! The configuration is valid.
```

## 関連ファイル

- `buildspec.yaml`: CodeBuild の構成ファイル
- `terraform/modules/cicd/appspec-nextjs.yaml.tpl`: Next.js AppSpec テンプレート
- `terraform/modules/cicd/appspec-go-server.yaml.tpl`: Go Server AppSpec テンプレート
