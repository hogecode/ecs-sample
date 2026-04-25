# マルチステージビルド：ビルドステージ
# AWS公式のGoイメージを使用
FROM public.ecr.aws/golang:1.21-alpine AS builder 

WORKDIR /app

# 必要なツールをインストール（ビルド用）
RUN apk add --no-cache git ca-certificates

# go.mod と go.sum をコピー
COPY go.mod go.sum ./

# 依存関係をダウンロード
RUN go mod download

# アプリケーションコードをコピー
COPY . .

# バイナリをビルド（oCGO_ENABLED=0を指定してスタティックリンク）
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server .

# 本番ステージ
FROM public.ecr.aws/alpine:latest

WORKDIR /root/

# 本番環境で必要な CA 証明書をコピー
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# ビルダーステージからバイナリをコピー
COPY --from=builder /app/server .

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/hello || exit 1

# ポート 8080 をエクスポート
EXPOSE 8080

# アプリケーションを実行
CMD ["./server"]
