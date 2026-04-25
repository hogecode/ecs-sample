# AppSpec ファイル - サービス別分離

## 概要
Next.js と Go Server のデプロイに異なる appspec ファイルを使用するように変更しました。

## 実装内容

### 1. テンプレートファイルの作成

#### `terraform/modules/cicd/appspec-nextjs.yaml.tpl`
- Next.js サービス用 appspec テンプレート
- コンテナ名: `ecs-sample-nextjs`
- コンテナポート: `3000`

#### `terraform/modules/cicd/appspec-go-server.yaml.tpl`
- Go Server サービス用 appspec テンプレート
- コンテナ名: `ecs-sample-go-server`
- コンテナポート: `8080`

### 2. CodePipeline 設定の更新

#### DeployNextJS ステージ
- `AppSpecTemplateArtifact = "appspec-nextjs.yaml"` に修正

#### DeployGoServer ステージ
- `AppSpecTemplateArtifact = "appspec-go-server.yaml"` に修正

## 利点

1. **サービス固有の設定**
   - 各サービスのコンテナ情報が正確に指定される

2. **保守性の向上**
   - サービスごとに独立した設定ファイルで管理

3. **デプロイの正確性**
   - プレースホルダーを使用せず、実際のコンテナ情報が含まれる

## 備考

- buildspec.yaml はそのまま変更なし
- 元の appspec.yaml はレガシー用として残される
