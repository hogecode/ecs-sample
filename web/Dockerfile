# マルチステージビルド：ビルドステージ
FROM node:20-alpine AS builder

WORKDIR /app

# package.json と package-lock.json をコピー
COPY package*.json ./

# 依存関係をインストール
RUN npm ci

# アプリケーションコードをコピー
COPY . .

# Next.js をビルド
RUN npm run build

# 本番ステージ
FROM node:20-alpine

WORKDIR /app

# 環境変数を設定
ENV NODE_ENV=production

# ビルダーステージから必要なファイルをコピー
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# ポート 3000 をエクスポート
EXPOSE 3000

# アプリケーションを起動
CMD ["npm", "start"]
