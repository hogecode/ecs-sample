# Hello World API - Server & Web Application

このプロジェクトは、Go の Gin フレームワークでバックエンド API を構築し、Next.js でフロントエンドから API を呼び出すシンプルな例です。

## プロジェクト構成

```
ecs-sample/
├── server/          # Go バックエンド (Gin フレームワーク)
│   ├── main.go      # API エンドポイント定義
│   ├── go.mod       # Go モジュール依存関係
│   └── go.sum       # Go モジュールチェックサム
└── web/             # Next.js フロントエンド
    ├── app/         # App Router ページコンポーネント
    │   ├── page.tsx    # メインページ (API呼び出し)
    │   ├── layout.tsx   # ルートレイアウト
    │   └── globals.css  # グローバルスタイル
    ├── package.json # npm 依存関係
    ├── next.config.js
    ├── tailwind.config.ts
    └── tsconfig.json
```

## セットアップ手順

### サーバーの起動

```bash
cd server
go mod tidy
go run main.go
```

サーバーは `http://localhost:8080` で起動します。

**API エンドポイント:**
- `GET /api/hello` - Hello World メッセージを返す

**レスポンス例:**
```json
{
  "message": "Hello, World!",
  "status": "success"
}
```

### Web アプリケーションの起動

```bash
cd web
npm install
npm run dev
```

Web アプリケーションは `http://localhost:3000` で起動します。

## 機能

### サーバー (Go + Gin)

- **Hello World API**: シンプルな REST API エンドポイント
- **CORS 対応**: フロントエンドからのリクエストを許可
- **ポート 8080**: 標準的な開発ポート

### Web (Next.js)

- **API 呼び出し**: useEffect を使用してマウント時に API を呼び出し
- **エラーハンドリング**: API エラーを適切に処理
- **ローディング状態**: API リクエスト中の UI 表示
- **Tailwind CSS**: スタイリング

## API テスト

### curl コマンドでテスト

```bash
curl http://localhost:8080/api/hello
```

### ブラウザで直接アクセス

```
http://localhost:8080/api/hello
```

## 開発環境

- **言語:** Go 1.21+, Node.js 18+
- **フレームワーク:** Gin v1.9.1, Next.js 14
- **スタイリング:** Tailwind CSS 3.3
- **パッケージマネージャー:** npm, go mod

## トラブルシューティング

### サーバーが起動しない場合

1. Go がインストールされているか確認: `go version`
2. ポート 8080 が使用可能か確認
3. 依存関係を更新: `go mod tidy`

### Web アプリケーションが起動しない場合

1. Node.js がインストールされているか確認: `node --version`
2. npm キャッシュをクリア: `npm cache clean --force`
3. node_modules を削除して再インストール: `npm install`

### API 呼び出しが失敗する場合

1. サーバーが起動しているか確認: `http://localhost:8080/api/hello`
2. ブラウザのコンソールでエラーを確認
3. サーバーログを確認して CORS エラーを探す

## 次のステップ

- データベースの統合
- 認証機能の追加
- API ドキュメンテーション (Swagger) の作成
- ユニットテストの追加
- Docker コンテナ化
