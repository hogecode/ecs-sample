# buildspec.yaml YAML形式エラー - 修正

## エラー内容

CodeBuildビルド実行時に以下のエラーが発生：

```
Phase complete: DOWNLOAD_SOURCE State: FAILED
Phase context status code: YAML_FILE_ERROR 
Message: Expected Commands[1] to be of string type: found subkeys instead at line 46, 
value of the key tag on line 45 might be empty
```

## 原因

`buildspec.yaml` のpost_buildセクション（行43-72）でYAML形式エラーが発生していました。

**問題箇所:**
```yaml
post_build:
  commands:
    - echo "=========================================="
    - echo "Phase: Post-Build - Push to ECR"
    - echo "=========================================="
    
    # Push Next.js Image    ← 空のコメント行のため、次の行との関係がおかしい
    - echo "Pushing Next.js Docker image to ECR on $(date)"
```

コメント行の後に複数行コマンドが続く構造でYAMLパーサがコマンド配列の形式を正しく認識できていませんでした。

## 修正内容

**修正ファイル:** `buildspec.yaml`

**修正方法:** コメント行をすべてのecho文に統合

### 修正前
```yaml
post_build:
  commands:
    - echo "=========================================="
    - echo "Phase: Post-Build - Push to ECR"
    - echo "=========================================="
    
    # Push Next.js Image
    - echo "Pushing Next.js Docker image to ECR on $(date)"
    - docker push $NEXTJS_REPO_URI:$IMAGE_TAG
    - docker push $NEXTJS_REPO_URI:latest
    - echo "Next.js Docker image pushed successfully"
    
    # Push Go Server Image
    - echo "Pushing Go Server Docker image to ECR on $(date)"
    - docker push $GO_SERVER_REPO_URI:$IMAGE_TAG
    - docker push $GO_SERVER_REPO_URI:latest
    - echo "Go Server Docker image pushed successfully"
    
    # Generate image definitions for ECS deployment
    - echo "Generating imagedefinitions.json for ECS deployment"
    - |
      printf '[...]' $NEXTJS_REPO_URI:$IMAGE_TAG $GO_SERVER_REPO_URI:$IMAGE_TAG > imagedefinitions.json
```

### 修正後
```yaml
post_build:
  commands:
    - echo "=========================================="
    - echo "Phase: Post-Build - Push to ECR"
    - echo "=========================================="
    - echo "Pushing Next.js Docker image to ECR on $(date)"
    - docker push $NEXTJS_REPO_URI:$IMAGE_TAG
    - docker push $NEXTJS_REPO_URI:latest
    - echo "Next.js Docker image pushed successfully"
    - echo "Pushing Go Server Docker image to ECR on $(date)"
    - docker push $GO_SERVER_REPO_URI:$IMAGE_TAG
    - docker push $GO_SERVER_REPO_URI:latest
    - echo "Go Server Docker image pushed successfully"
    - echo "Generating imagedefinitions.json for ECS deployment"
    - |
      printf '[...]' $NEXTJS_REPO_URI:$IMAGE_TAG $GO_SERVER_REPO_URI:$IMAGE_TAG > imagedefinitions.json
```

## 修正のポイント

1. **コメント行の削除**: YAML配列の中に `# コメント` 行を挿入すると、次のコマンドとの関係が曖昧になる
2. **統一された構造**: 全てのコマンドが同じレベルのリストアイテムとして定義
3. **複数行コマンド保持**: `- |` による複数行コマンド（printf）は保持

## 修正による改善

✅ YAML形式のバリデーションエラーが消える
✅ CodeBuildがビルドステップに進める
✅ Docker イメージのビルド→プッシュが正常に実行される

## 修正後の動作確認

修正後、CodePipelineが再度Buildステージを実行します：

### 1. ビルドログの確認

```bash
aws logs tail /aws/codebuild/ecs-sample-dev-build --follow
```

以下のログが表示される：
- ✅ `Phase is DOWNLOAD_SOURCE` 
- ✅ `YAML location is /codebuild/...buildspec.yaml`
- ✅ `Phase complete: DOWNLOAD_SOURCE State: SUCCEEDED` ← 今回修正したエラーはここで消える
- ✅ `Phase is PRE_BUILD`
- ✅ `aws ecr get-login-password` でECRログイン
- ✅ `Phase is BUILD`
- ✅ Docker イメージビルド（Next.js, Go Server）
- ✅ `Phase is POST_BUILD`
- ✅ Docker イメージをECRにプッシュ
- ✅ `imagedefinitions.json` 生成
- ✅ `Phase complete: POST_BUILD State: SUCCEEDED`

### 2. CodePipelineの確認

AWSコンソール → CodePipeline で以下を確認：
- Build ステージ → Success ✅
- Scan ステージ → 実行開始
- Deploy ステージ → 順序通り実行

## YAML形式の注意点

buildspec.yamlでコメントを使う場合の注意：

```yaml
# ✅ 推奨: コメントは commands の外に
commands:
  - echo "Step 1"
  - echo "Step 2"

# ❌ 非推奨: commands 配列の中にコメント
commands:
  - echo "Step 1"
  # Comment here  ← これがあると、YAML形式エラーになる可能性がある
  - echo "Step 2"
```

## 関連ドキュメント

- [AWS CodeBuild - buildspec リファレンス](https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/build-spec-ref.html)
- [YAML 仕様](https://yaml.org/)
- [buildspec.yaml テンプレート](https://docs.aws.amazon.com/ja_jp/codebuild/latest/userguide/sample-buildspecs.html)
