# AWS Secrets Manager 接続エラー修正ドキュメント

## 問題の分析

### エラーログの内容
```
2026/04/30 10:25:22 Failed to connect to database: failed to get secret from Secrets Manager: 
operation error Secrets Manager: GetSecretValue, https response error StatusCode: 0, 
RequestID: , canceled, context deadline exceeded
```

### 根本原因
1. **Go サーバーアプリケーション実装不足**
   - AWS SDK v2 (Secrets Manager) のインポートがなかった
   - Secrets Manager から秘密を取得するコードが実装されていなかった
   - DB 接続ロジックが完全に欠落していた

2. **go.mod の依存関係不足**
   - `github.com/aws/aws-sdk-go-v2/config` がなかった
   - `github.com/aws/aws-sdk-go-v2/service/secretsmanager` がなかった

### インフラストラクチャ側は正しく設定済み ✅
- ✅ VPC エンドポイント (Secrets Manager) が設定済み
- ✅ ECS タスク実行ロールに `secretsmanager:GetSecretValue` 権限がある
- ✅ IAM ポリシーで KMS デコード権限も設定済み
- ✅ セキュリティグループルールが正しく設定済み

## 実装した修正内容

### 1. `server/main.go` の完全な実装

#### 追加された機能
- **AWS SDK v2 の統合**
  - `config.LoadDefaultConfig()` で AWS 認証情報を自動取得
  - ECS Fargate の IAM ロールを使用した認証

- **Secrets Manager からの秘密取得**
  ```go
  func getSecretFromSecretsManager(ctx context.Context, secretARN string) (string, error)
  ```
  - `DB_CREDENTIALS_SECRET_ARN` 環境変数から ARN を取得
  - タイムアウト付きで秘密を取得（10秒）
  - エラーハンドリング付き

- **DB 認証情報の解析**
  ```go
  func parseDBCredentials(secretString string) (*DBCredentials, error)
  ```
  - JSON 形式の秘密を構造体にパース
  - 以下の情報を抽出:
    - `username`: DB ユーザー名
    - `password`: DB パスワード
    - `host`: DB ホスト名
    - `database`: DB 名
    - `port`: DB ポート
    - `engine`: DB エンジン (mysql, postgres など)

#### API エンドポイント
| エンドポイント | 説明 | レスポンス例 |
|---|---|---|
| `GET /api/health` | ヘルスチェック | ステータス + DB 接続情報 |
| `GET /api/hello` | Hello World | 簡単なメッセージ |
| `GET /api/info` | サーバー情報 | アプリ情報 + DB 詳細 |

### 2. `server/go.mod` の依存関係更新

追加した依存関係:
```go
require (
	github.com/gin-gonic/gin v1.9.1
	github.com/aws/aws-sdk-go-v2/config v1.27.0
	github.com/aws/aws-sdk-go-v2/service/secretsmanager v1.28.0
)
```

AWS SDK v2 の依存関係チェーン：
- `aws-sdk-go-v2/config` - AWS SDK の設定・認証
- `aws-sdk-go-v2/service/secretsmanager` - Secrets Manager クライアント
- その他の AWS SDK コアライブラリ（自動的に解決）

## 動作フロー

```
┌─────────────────────────────────────────────────────────────┐
│ ECS Fargate の Go サーバー起動                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. AWS SDK を初期化 (IAM ロール認証)                         │
│    - ECS Fargate の タスク実行ロールを使用                  │
│    - VPC エンドポイント経由で AWS API にアクセス            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Secrets Manager から DB 秘密を取得                       │
│    - ARN: arn:aws:secretsmanager:ap-northeast-1:...:secret:...│
│    - リトライ + タイムアウト (10秒)                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. JSON を解析して DB 接続情報を取得                        │
│    - username, password, host, port, database など          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Gin HTTP サーバーを起動 (:8080)                          │
│    - /api/health - DB 情報付きヘルスチェック                │
│    - /api/hello  - シンプルな応答                           │
│    - /api/info   - サーバー情報                             │
└─────────────────────────────────────────────────────────────┘
```

## VPC エンドポイント経由のアクセス

### Secrets Manager VPC エンドポイント設定
```terraform
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [...]
  security_group_ids  = [...]
}
```

### セキュリティグループルール
```terraform
resource "aws_security_group_rule" "vpc_endpoints_from_go_server" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.go_server_sg.security_group_id
  security_group_id        = module.vpc_endpoints_sg.security_group_id
}
```

## Docker ビルド時の動作

Dockerfile では `go mod tidy` と `go mod download` が自動実行されます：

```dockerfile
COPY go.mod go.sum ./
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server .
```

## テスト方法

### ローカルテスト（AWS 認証情報が必要）
```bash
cd server
go mod tidy
go run main.go
# ブラウザで http://localhost:8080/api/health にアクセス
```

### ECS での実行確認
```bash
# ECS サービスのログをチェック
aws logs tail /ecs/ecs-sample-go-server-dev --follow

# 成功時のログ例:
# 2026/04/30 10:30:00 Successfully loaded database credentials for host: db.example.com
# Starting server on :8080
```

### API エンドポイントの確認
```bash
curl http://alb-dns-name/api/health
curl http://alb-dns-name/api/hello
curl http://alb-dns-name/api/info
```

## トラブルシューティング

### エラー: "Failed to get secret from Secrets Manager"

**原因 1: IAM 権限不足**
```
解決: ECS タスク実行ロールに以下を追加
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:ap-northeast-1:*:secret:ecs-sample/*"
}
```

**原因 2: VPC エンドポイント設定なし**
```
解決: VPC エンドポイント (Secrets Manager) を作成・設定
- プライベートサブネットから HTTPS (443) アクセス可能にする
- セキュリティグループで ECS タスク SG からのアクセスを許可
```

**原因 3: KMS 復号化権限不足**
```
解決: IAM ロールに KMS デコード権限を追加
{
  "Effect": "Allow",
  "Action": ["kms:Decrypt"],
  "Resource": "*"
}
```

**原因 4: 環境変数 `DB_CREDENTIALS_SECRET_ARN` が設定されていない**
```
解決: ECS タスク定義で環境変数を設定
"environment": [
  {
    "name": "DB_CREDENTIALS_SECRET_ARN",
    "value": "arn:aws:secretsmanager:ap-northeast-1:885545925004:secret:ecs-sample/db/app-credentials-..."
  }
]
```

## 参考資料

- [AWS SDK for Go v2 - Getting Started](https://aws.github.io/aws-sdk-go-v2/docs/getting-started/)
- [AWS Secrets Manager - Go の例](https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets.html)
- [ECS Fargate IAM ロール](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)
- [VPC エンドポイント - Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html)

## 修正履歴

| 日時 | 修正内容 | 詳細 |
|---|---|---|
| 2026-04-30 | Go サーバー実装完成 | AWS SDK v2 統合、Secrets Manager 取得機能追加 |
| 2026-04-30 | go.mod 依存関係更新 | aws-sdk-go-v2 パッケージ追加 |
