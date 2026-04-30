import axios from 'axios';

/**
 * API クライアント設定
 * 
 * サーバーサイド（SSR）でのみ実行
 * API_BASE_URL 環境変数から Base URL を取得（taskdef.json で注入）
 */
const apiClient = axios.create({
  baseURL: `${process.env.API_BASE_URL}:8080`,
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
 * サーバーサイド（SSR）でのみ実行されます
 */
export async function fetchHelloMessage() {
  try {
    const response = await apiClient.get('/api/hello');
    return response.data;
  } catch (error) {
    throw error;
  }
}

/**
 * 従業員一覧を取得
 */
export async function fetchEmployees(limit: number = 10, offset: number = 0) {
  try {
    const response = await apiClient.get('/api/employees', {
      params: { limit, offset },
    });
    return response.data;
  } catch (error) {
    throw error;
  }
}

/**
 * 従業員詳細を取得
 */
export async function fetchEmployeeById(id: number) {
  try {
    const response = await apiClient.get(`/api/employees/${id}`);
    return response.data;
  } catch (error) {
    throw error;
  }
}

/**
 * 従業員を作成
 */
export async function createEmployee(employee: {
  name: string;
  email: string;
  department: string;
  salary: number;
}) {
  try {
    const response = await apiClient.post('/api/employees', employee);
    return response.data;
  } catch (error) {
    throw error;
  }
}

/**
 * 従業員を更新
 */
export async function updateEmployee(
  id: number,
  employee: {
    name: string;
    email: string;
    department: string;
    salary: number;
  }
) {
  try {
    const response = await apiClient.put(`/api/employees/${id}`, employee);
    return response.data;
  } catch (error) {
    throw error;
  }
}

/**
 * 従業員を削除
 */
export async function deleteEmployee(id: number) {
  try {
    const response = await apiClient.delete(`/api/employees/${id}`);
    return response.data;
  } catch (error) {
    throw error;
  }
}
