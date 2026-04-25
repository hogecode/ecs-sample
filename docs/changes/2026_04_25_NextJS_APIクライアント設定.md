# Next.js API クライアント設定 - 内部ALB連携

**日付:** 2026-04-25  
**対象:** web/（Next.js フロントエンド）

## 概要

Next.js から Go Server API へアクセスする際の axios クライアント設定方法を説明します。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                     Next.js ECS                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  React Component                                      │   │
│  │         ↓                                             │   │
│  │  axios client (NEXT_PUBLIC_API_BASE_URL)            │   │
│  │         ↓                                             │   │
│  │  Private ALB DNS                                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                      ↓                                        │
│            Private ALB (内部ロードバランサー)                 │
│                      ↓                                        │
│            Go Server ECS (ポート 8080)                       │
└─────────────────────────────────────────────────────────────┘
```

## Terraform 環境変数設定

### `terraform/environments/dev.tfvars`

```hcl
nextjs_environment_variables = [
  {
    name  = "NEXT_PUBLIC_API_BASE_URL"
    value = "http://ecs-sample-private-alb-dev.ap-northeast-1.elb.amazonaws.com"
  },
  {
    name  = "API_BASE_URL"
    value = "http://ecs-sample-private-alb-dev.ap-northeast-1.elb.amazonaws.com"
  },
  {
    name  = "NODE_ENV"
    value = "production"
  }
]
```

**注：** ALB DNSは自動生成されます（terraform apply後に確認可能）

## Next.js 側の実装

### 1. axios クライアント設定

**`web/lib/api-client.ts`** を新規作成：

```typescript
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

/**
 * API Base URL Configuration
 * - NEXT_PUBLIC_API_BASE_URL: ブラウザ & サーバー側で使用
 * - API_BASE_URL: サーバー側のみで使用（プライベート）
 */
const apiBaseUrl = 
  process.env.NEXT_PUBLIC_API_BASE_URL || 
  process.env.API_BASE_URL || 
  'http://localhost:8080';

/**
 * Axios インスタンス作成
 */
export const apiClient: AxiosInstance = axios.create({
  baseURL: apiBaseUrl,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * レスポンスインターセプター
 */
apiClient.interceptors.response.use(
  response => response,
  error => {
    console.error('API Error:', error.message);
    return Promise.reject(error);
  }
);

export default apiClient;
```

### 2. API サービス層

**`web/lib/services/go-api.ts`** を新規作成：

```typescript
import apiClient from '@/lib/api-client';

/**
 * Go Server API Service
 */
export const goApiService = {
  /**
   * ヘルスチェック
   */
  async getHealth() {
    const response = await apiClient.get('/health');
    return response.data;
  },

  /**
   * ユーザー情報取得
   */
  async getUser(userId: string) {
    const response = await apiClient.get(`/api/users/${userId}`);
    return response.data;
  },

  /**
   * ユーザー情報更新
   */
  async updateUser(userId: string, data: any) {
    const response = await apiClient.put(`/api/users/${userId}`, data);
    return response.data;
  },

  /**
   * リスト取得
   */
  async getItems(params?: any) {
    const response = await apiClient.get('/api/items', { params });
    return response.data;
  },

  /**
   * アイテム作成
   */
  async createItem(data: any) {
    const response = await apiClient.post('/api/items', data);
    return response.data;
  },
};
```

### 3. React Component での使用

**`web/app/components/UserProfile.tsx`** の例：

```typescript
'use client';

import { useEffect, useState } from 'react';
import { goApiService } from '@/lib/services/go-api';

export default function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        setLoading(true);
        const data = await goApiService.getUser(userId);
        setUser(data);
        setError(null);
      } catch (err: any) {
        setError(err.message);
        console.error('Failed to fetch user:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, [userId]);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!user) return <div>No user found</div>;

  return (
    <div>
      <h1>{user.name}</h1>
      <p>Email: {user.email}</p>
    </div>
  );
}
```

## 環境変数の詳細

### NEXT_PUBLIC_API_BASE_URL

- **用途**: ブラウザ側 & サーバー側の両方で使用
- **設定値**: `http://ecs-sample-private-alb-dev.ap-northeast-1.elb.amazonaws.com`
- **アクセス**: `process.env.NEXT_PUBLIC_API_BASE_URL`
- **特徴**: 
  - `NEXT_PUBLIC_` プレフィックスがあるため、ブラウザに露出
  - VPC内通信なので直接ALBにアクセス可能

### API_BASE_URL

- **用途**: サーバー側のみで使用（プライベート）
- **アクセス**: `process.env.API_BASE_URL`（サーバー側のみ）
- **用例**: API ルート (`app/api/*`) でバックエンド呼び出し時

## Next.js のサーバーサイド処理での利用例

**`web/app/api/proxy/[...path]/route.ts`** の例：

```typescript
import { NextRequest, NextResponse } from 'next/server';

export async function GET(
  request: NextRequest,
  { params }: { params: { path: string[] } }
) {
  const apiBaseUrl = process.env.API_BASE_URL || 'http://localhost:8080';
  const path = params.path.join('/');

  try {
    const response = await fetch(`${apiBaseUrl}/${path}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('API Proxy Error:', error);
    return NextResponse.json(
      { error: 'API call failed' },
      { status: 500 }
    );
  }
}
```

## 設定の検証

### 1. ローカル開発環境

```bash
# .env.local
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
API_BASE_URL=http://localhost:8080
```

### 2. AWS 環境での確認

ECS タスク定義で環境変数を確認：

```bash
aws ecs describe-task-definition \
  --task-definition ecs-sample-nextjs:latest \
  --query 'taskDefinition.containerDefinitions[0].environment[]'
```

### 3. Next.js コンテナ内での確認

```bash
# コンテナにエクスポート
docker exec <container_id> env | grep API_BASE_URL
```

## トラブルシューティング

### エラー: `connect ECONNREFUSED`

**原因**: Next.js → 内部ALB の通信が失敗

**解決策**:
1. セキュリティグループ確認: NextJS → 内部ALB の通信許可
2. 内部ALB のリスナー設定確認: ポート 80 が開いているか
3. Go Server ターゲットグループのヘルスチェック確認

### エラー: `404 Not Found`

**原因**: API パスが間違っているか、Go Server API エンドポイントが存在しない

**解決策**:
1. Go Server のルーティング確認
2. 内部ALB のパスベースルーティング設定確認
3. リクエストログを確認: `aws logs tail /ecs/ecs-sample-go-server-dev`

### エラー: `Connection timeout`

**原因**: Go Server が起動していない、またはタスクが停止している

**解決策**:
1. ECS タスク状態確認: `aws ecs describe-services --cluster ecs-sample-cluster-dev --services ecs-sample-go-server-service`
2. Go Server ログ確認: `aws logs tail /ecs/ecs-sample-go-server-dev`
3. ALB のターゲットヘルスチェック確認

## セキュリティ考慮事項

⚠️ **VPC 内通信**
- 内部ALBへのアクセスは VPC 内のみ
- ブラウザからのリクエストは同じ VPC 内の NextJS から発信

⚠️ **HTTPS への移行**
- 本番環境では `https://` を使用
- ACM 証明書を設定してALBを HTTPS 化

⚠️ **認証・認可**
- 必要に応じて JWT トークン等の認証機構を追加

## 参考

- Terraform ALB モジュール: `terraform/modules/network/alb/`
- ECS モジュール: `terraform/modules/compute/ecs/`
- 関連ドキュメント:
  - [Next.js 環境変数](https://nextjs.org/docs/basic-features/environment-variables)
  - [Axios ドキュメント](https://axios-http.com/)
