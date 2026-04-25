# CodeBuild GitHub Source設定の置き換え

**日付**: 2026-04-25  
**対象**: Terraform CI/CDモジュール

## 概要

CodeBuildプロジェクトのソース設定を、CodePipelineから直接GitHubへの設定に変更しました。

## 変更内容

### 1. `terraform/modules/cicd/main.tf` の修正

#### 変更前
- `aws_codebuild_project.build_project`:
  ```hcl
  artifacts {
    type = "CODEPIPELINE"
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
  ```

- `aws_codebuild_project.scan_project`:
  ```hcl
  artifacts {
    type = "CODEPIPELINE"
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-scan.yaml"
  }
  ```

#### 変更後
- `aws_codebuild_project.build_project`:
  ```hcl
  artifacts {
    type         = "NO_ARTIFACTS"
    name         = null
  }
  
  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repository_id}.git"
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }
  ```

- `aws_codebuild_project.scan_project`:
  ```hcl
  artifacts {
    type         = "NO_ARTIFACTS"
    name         = null
  }
  
  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repository_id}.git"
    git_clone_depth = 1
    buildspec       = "buildspec-scan.yml"
  }
  ```

**変更点**:
- `artifacts.type`: `"CODEPIPELINE"` → `"NO_ARTIFACTS"`（AWS CodeBuildの制約により必須）
- `source.type`: `"CODEPIPELINE"` → `"GITHUB"`
- `source.location`: GitHub リポジトリへの直接参照を追加
- `source.git_clone_depth`: `1` に設定（浅いクローン）
- `buildspec`: `.yaml` → `.yml` に拡張子を変更

### 2. `terraform/modules/cicd/variables.tf` に新変数を追加

```hcl
variable "github_repository_id" {
  description = "GitHub repository ID in format 'owner/repo' for CodeBuild source"
  type        = string
  default     = "hogecode/ecs-sample"
}
```

**説明**:
- CodeBuildが直接GitHubリポジトリからソースコードを取得する際に使用
- デフォルト値: `"hogecode/ecs-sample"`

## 利点

1. **直接接続**: CodeBuildがGitHubから直接ソースコードを取得
2. **シンプルな構成**: CodePipelineを介さない直接接続により構成が簡潔
3. **浅いクローン**: `git_clone_depth = 1` でダウンロードサイズを最小化
4. **柔軟な設定**: リポジトリIDを変数で管理可能

## 確認項目

- [ ] buildspec.yml と buildspec-scan.yml の拡張子が正しく設定されていることを確認
- [ ] GitHub認証情報が正しく設定されていることを確認（AWS CodeBuild の認証設定）
- [ ] CodePipelineの設定で、Source Stageの設定がこの変更と整合していることを確認

## 関連ファイル

- `terraform/modules/cicd/main.tf`
- `terraform/modules/cicd/variables.tf`
- `buildspec.yml`
- `buildspec-scan.yml`
