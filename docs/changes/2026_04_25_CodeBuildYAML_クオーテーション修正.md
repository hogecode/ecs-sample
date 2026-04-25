# CodeBuild YAML File Error 対処：クオーテーション修正

## 概要

CodeBuildの`buildspec.yaml`と`buildspec-scan.yaml`にYAML解析エラー対策としてクオーテーション修正を実施しました。

**参考記事：** https://www.bioerrorlog.work/entry/codebuild-colon-error

## 問題点

CodeBuildで以下のエラーが発生する可能性があります：

```
YAML_FILE_ERROR Message: Expected Commands[0] to be of string type: 
found subkeys instead at line X, value of the key tag on line Y might be empty
```

### 原因

YAMLフォーマット内に**「コロン（:）+ スペース（ ）」**の組み合わせがコマンドに含まれていると、YAMLパーサーがこの部分をサブキー（ネストされたキー）として誤解釈します。

例：
```yaml
# ❌ エラーの原因
- echo "Logging in to ECR at $(date)"  # 「: 」がサブキーと誤認識
```

## 解決策

### アプローチ：「コロン + スペース」を避ける（推奨）

記事で推奨される最適な解決策は、**「コロン + スペース」の組み合わせを避ける**ことです。

```yaml
# ✅ 修正後（推奨）
- echo "Phase Pre-Build AWS ECR Login"  # コロンを削除
- "echo \"Logging in to ECR at $(date)\""  # クオーテーションで保護

# または
- echo "Image Tag - $IMAGE_TAG"  # ハイフンに置き換え
```

このアプローチは以下の利点があります：
- YAMLパーサーの誤解釈を完全に回避
- コマンド出力がシンプルで読みやすい
- 環境変数展開が正常に機能


## 修正対象ファイル

### 1. buildspec.yaml

**修正フェーズ：**

#### pre_build フェーズ
- `- echo "Logging in to ECR at $(date)"` → `- "echo \"Logging in to ECR at $(date)\""`
- 環境変数設定コマンドをクオーテーション
- ECRログメッセージのクオーテーション

#### build フェーズ
- Docker build コマンドのクオーテーション
- ビルドログメッセージのクオーテーション

#### post_build フェーズ
- Docker push コマンドのクオーテーション
- プッシュログメッセージのクオーテーション

**修正ライン数：** 計14行

### 2. buildspec-scan.yaml

**修正フェーズ：**

#### pre_build フェーズ
- Trivyインストールログのクオーテーション
- キーのダウンロードコマンドをクオーテーション
- リポジトリ追加コマンドをクオーテーション

#### build フェーズ
- スキャンログメッセージのクオーテーション
- 環境変数設定コマンドをクオーテーション
- Trivyスキャンコマンドのクオーテーション

**修正ライン数：** 計8行

## 修正内容の詳細

### 修正前後の比較

```yaml
# buildspec.yaml - pre_build フェーズ例

# ❌ 修正前
- echo "Phase: Pre-Build - AWS ECR Login"  # 「: 」がサブキーと誤認識
- NEXTJS_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$NEXTJS_REPO_NAME
- IMAGE_TAG=${COMMIT_HASH:=latest}  # 「:= 」の部分が問題

# ✅ 修正後（推奨）
- echo "Phase Pre-Build AWS ECR Login"  # コロンを削除
- "NEXTJS_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$NEXTJS_REPO_NAME"
- "IMAGE_TAG=${COMMIT_HASH:=latest}"  # 全体をクオーテーション
```

```yaml
# buildspec-scan.yaml - build フェーズ例

# ❌ 修正前
- echo "Scanning image: $REPOSITORY_URI:$IMAGE_TAG"  # 「: 」がサブキーと誤認識

# ✅ 修正後（推奨）
- "echo \"Scanning image - $REPOSITORY_URI:$IMAGE_TAG\""  # コロン→ハイフン、全体をクオーテーション
```

### 修正ポイント

#### 1. echo コマンドのコロン削除
```yaml
# 修正前
- echo "Phase: Build - Docker Images Build"

# 修正後
- echo "Phase Build Docker Images Build"
```

#### 2. 複雑なコマンドのクオーテーション
```yaml
# 修正前
- NEXTJS_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$NEXTJS_REPO_NAME

# 修正後
- "NEXTJS_REPO_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$NEXTJS_REPO_NAME"
```

#### 3. 出力メッセージの変更
```yaml
# 修正前
- echo "Next.js Repository URI: $NEXTJS_REPO_URI"

# 修正後
- "echo \"Next.js Repository URI - $NEXTJS_REPO_URI\""
```

## 重要な注意事項

### クオーテーション規則

1. **外側のクオーテーション：** コマンド全体を含む行
   ```yaml
   - "command with: special characters"
   ```

2. **内側のクオーテーション：** echoコマンド内の出力テキスト
   ```yaml
   - "echo \"Text to output\""
   ```

3. **複雑なコマンド（パイプ/リダイレクト）：** マルチラインコマンドブロックは `|` で指定
   ```yaml
   - |
     trivy image --format json ... | jq '[...]'
   ```

### 環境変数展開の確認

修正後も環境変数展開は正常に機能します：
- `$AWS_DEFAULT_REGION`
- `$AWS_ACCOUNT_ID`
- `$(date)` （コマンド置換）

## テスト方法

修正後、以下の方法でYAML形式を検証できます：

```bash
# YAML構文チェック
yamllint buildspec.yaml
yamllint buildspec-scan.yaml

# CodeBuild プロジェクトでテストビルド実行
aws codebuild start-build --project-name <project-name>
```

## 参考資料

- **AWS CodeBuild ドキュメント：** https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html#build-spec-ref-syntax
- **BioErrorLog Tech Blog 記事：** https://www.bioerrorlog.work/entry/codebuild-colon-error

## 修正者

実装日時：2026年4月25日

## チェックリスト

- [x] buildspec.yaml のクオーテーション修正
- [x] buildspec-scan.yaml のクオーテーション修正
- [x] ドキュメント作成
- [ ] テストビルド実行
- [ ] CI/CDパイプラインでの動作確認
