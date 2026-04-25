# CodeBuild Scan ステージ - 複数イメージ対応修正

**日付:** 2026-04-25  
**対象:** buildspec-scan.yaml

## 概要

buildspec-scan.yaml を修正し、CodeBuild の Scan ステージで NextJS と Go Server の両方のイメージを Trivy でスキャンできるようにしました。

## 問題点

以前のバージョンでは以下の課題がありました：

```
unable to parse reference: .dkr.ecr.ap-northeast-1.amazonaws.com/:efacbcf
```

**原因：**
- 環境変数 `IMAGE_REPO_NAME` が CodeBuild プロジェクトで定義されていなかった
- Build ステージは `NEXTJS_REPO_NAME` と `GO_SERVER_REPO_NAME` を使用しているが、Scan ステージが異なる環境変数を参照していた

## 実装内容

### 1. 環境変数の変更

**修正前：**
```bash
REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME
```

**修正後：**
```bash
NEXTJS_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$NEXTJS_REPO_NAME
GO_SERVER_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$GO_SERVER_REPO_NAME
```

### 2. スキャン処理の分離

NextJS と Go Server それぞれ個別にスキャンを実行：

- **Next.js Image スキャン**
  - Trivy で HIGH/CRITICAL 脆弱性をスキャン
  - CRITICAL 脆弱性が見つかった場合はビルド失敗
  - スキャン結果を `nextjs-scan-results.json` に出力

- **Go Server Image スキャン**
  - Trivy で HIGH/CRITICAL 脆弱性をスキャン
  - CRITICAL 脆弱性が見つかった場合はビルド失敗
  - スキャン結果を `go-server-scan-results.json` に出力

### 3. Artifacts セクションの更新

```yaml
artifacts:
  files:
    - nextjs-scan-results.json
    - go-server-scan-results.json
  name: ScanArtifact
```

## 環境変数の要件

Terraform で CodeBuild Scan プロジェクトの環境変数として以下を設定：

```hcl
environment_variable {
  name  = "AWS_DEFAULT_REGION"
  value = var.aws_region
}

environment_variable {
  name  = "AWS_ACCOUNT_ID"
  value = data.aws_caller_identity.current.account_id
}

environment_variable {
  name  = "NEXTJS_REPO_NAME"
  value = var.ecr_nextjs_repository_name
}

environment_variable {
  name  = "GO_SERVER_REPO_NAME"
  value = var.ecr_go_server_repository_name
}
```

## スキャン結果

- `nextjs-scan-results.json`: Next.js コンテナイメージの脆弱性スキャン結果
- `go-server-scan-results.json`: Go Server コンテナイメージの脆弱性スキャン結果

両方のファイルが CodePipeline アーティファクトとして保存されます。

## テスト方法

CodePipeline を実行して Scan ステージが正常に動作することを確認：

1. 両方のイメージが正常にスキャンされること
2. スキャン結果ファイルが生成されること
3. CRITICAL 脆弱性がある場合にビルドが失敗すること

## 参考

- [Trivy 公式ドキュメント](https://aquasecurity.github.io/trivy/)
- 関連ファイル：
  - buildspec-scan.yaml
  - terraform/modules/cicd/main.tf (CodeBuild Scan プロジェクト設定)
