import axios from 'axios';

/**
 * API クライアント設定
 * 
 * NEXT_PUBLIC_API_BASE_URL 環境変数から Base URL を取得
 * Next.js の NEXT_PUBLIC_ プリフィックスにより、ブラウザで直接アクセス可能
 */
export const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * API リクエストインターセプタ（エラーハンドリング）
 */
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // サーバーがエラーレスポンスを返した
      console.error('API Error:', error.response.status, error.response.data);
    } else if (error.request) {
      // リクエストは送信されたがレスポンスがない
      console.error('No Response:', error.request);
    } else {
      // リクエスト設定エラー
      console.error('Error', error.message);
    }
    return Promise.reject(error);
  }
);

/**
 * Hello API を呼び出す
 */
export async function fetchHelloMessage() {
  try {
    const response = await apiClient.get('/api/hello');
    return response.data;
  } catch (error) {
    throw error;
  }
}
