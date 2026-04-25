# AWS ECR Public イメージ移行

## 概要

Docker Hub のレート制限問題を根本的に解決するために、すべての base イメージを **AWS ECR Public** に移行しました。

## 問題点

CodeBuild での Docker ビルド時に、Docker Hub の認証なしダウンロード制限に達成していました：

```
toomanyrequests: You have reached your unauthenticated pull rate limit
```

**Docker Hub の制限**
- 無認証：6時間で100プル（**制限に達した**）
- 認証済み（無料）：6時間で200プル

## 解決策

### AWS ECR Public への移行

AWS が公開している ECR Public リポジトリを使用することで：
- ✅ Docker Hub のレート制限が完全に回避される
- ✅ AWS インフラ内でのダウンロード（高速・低レイテンシ）
- ✅ 追加の認証設定が不要
- ✅ コスト効率的（AWS 内での転送）

## 修正内容

### 1. web/Dockerfile

#### ビルドステージ
```dockerfile
# 修正前
FROM node:20-alpine AS builder

# 修正後
FROM public.ecr.aws/docker/library/node:20-alpine AS builder
```

#### 本番ステージ
```dockerfile
# 修正前
FROM node:20-alpine

# 修正後
FROM public.ecr.aws/docker/library/node:20-alpine
```

### 2. server/Dockerfile

#### ビルドステージ
```dockerfile
# 修正前
FROM golang:1.21-alpine AS builder

# 修正後
FROM public.ecr.aws/golang:1.21-alpine AS builder
```

#### 本番ステージ
```dockerfile
# 修正前
FROM alpine:latest

# 修正後
FROM public.ecr.aws/alpine:latest
```

## AWS ECR Public URL パターン

AWS ECR Public では以下のパターンで base イメージにアクセスできます：

| カテゴリ | Docker Hub | AWS ECR Public |
|---------|-----------|----------------|
| **公式イメージ** | `node:20-alpine` | `public.ecr.aws/docker/library/node:20-alpine` |
| **言語別** | `golang:1.21-alpine` | `public.ecr.aws/golang:1.21-alpine` |
| **基本OS** | `alpine:latest` | `public.ecr.aws/alpine:latest` |

## 利点

### パフォーマンス
- AWS リージョン内での高速ダウンロード
- ネットワークレイテンシの低減
- キャッシュ効率の向上

### コスト
- AWS 内のデータ転送が無料
- Docker Hub の有料プランが不要

### 運用性
- 追加の認証管理が不要
- AWS IAM による統一的な権限管理
- Secrets Manager の設定が不要

## 動作確認

CodeBuild でビルドを実行して、以下を確認してください：

```bash
# CodeBuild のビルドログを確認
docker pull public.ecr.aws/docker/library/node:20-alpine
docker build -t <image-name> .
```

**期待される結果**
- レート制限エラーが発生しない
- ビルドが正常に完了する
- imagedefinitions.json が生成される

## 関連ドキュメント

- **BioErrorLog 記事**：https://www.bioerrorlog.work/entry/codebuild-colon-error
- **AWS ECR Public ドキュメント**：https://docs.aws.amazon.com/AmazonECR/latest/userguide/public-repositories.html
- **利用可能なイメージ一覧**：https://gallery.ecr.aws/

## 修正日時

2026年4月25日

## チェックリスト

- [x] web/Dockerfile のビルドステージを修正
- [x] web/Dockerfile の本番ステージを修正
- [x] server/Dockerfile のビルドステージを修正
- [x] server/Dockerfile の本番ステージを修正
- [x] ドキュメント作成
- [ ] CodeBuild でテスト実行
- [ ] 本番環境での動作確認
