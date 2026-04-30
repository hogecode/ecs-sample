// SSGを無効化して、常に最新のデータを取得するようにする
export const dynamic = 'force-dynamic'

import { getHomeData } from '@/lib/api/home';

export default async function Home() {
  const { message, error } = await getHomeData();

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-blue-50 to-blue-100">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full">
        <h1 className="text-3xl font-bold text-center text-blue-600 mb-6">
          Hello World API
        </h1>
        
        <div className="space-y-4">
          <div className="border-2 border-blue-300 rounded-lg p-6 bg-blue-50">
            {error ? (
              <div className="text-center">
                <p className="text-red-600 font-semibold">エラーが発生しました</p>
                <p className="text-red-500 text-sm mt-2">{error}</p>
              </div>
            ) : (
              <p className="text-center text-2xl font-semibold text-blue-700">
                {message}
              </p>
            )}
          </div>

          <p className="text-center text-gray-600 text-sm">
            バックエンド: {process.env.API_BASE_URL}
          </p>
        </div>
      </div>
    </main>
  );
}
