import { fetchHelloMessage } from '@/lib/api/api';

interface ApiResponse {
  message: string;
  status: string;
}

interface HomeData {
  message: string;
  error: string | null;
}

export async function getHomeData(): Promise<HomeData> {
  try {
    const data: ApiResponse = await fetchHelloMessage();
    return {
      message: data.message,
      error: null,
    };
  } catch (err) {
    return {
      message: 'Failed to fetch message',
      error: err instanceof Error ? err.message : 'An error occurred',
    };
  }
}
