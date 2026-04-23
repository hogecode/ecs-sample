'use client';

import { useState, useEffect } from 'react';

interface ApiResponse {
  message: string;
  status: string;
}

export default function Home() {
  const [message, setMessage] = useState<string>('Loading...');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchHello = async () => {
      try {
        setLoading(true);
        setError(null);
        
        const response = await fetch('http://localhost:8080/api/hello');
        
        if (!response.ok) {
          throw new Error(`API Error: ${response.status}`);
        }
        
        const data: ApiResponse = await response.json();
        setMessage(data.message);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
        setMessage('Failed to fetch message');
      } finally {
        setLoading(false);
      }
    };

    fetchHello();
  }, []);

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-blue-50 to-blue-100">
      <div className="bg-white rounded-lg shadow-lg p-8 max-w-md w-full">
        <h1 className="text-3xl font-bold text-center text-blue-600 mb-6">
          Hello World API
        </h1>
        
        <div className="space-y-4">
          <div className="border-2 border-blue-300 rounded-lg p-6 bg-blue-50">
            {loading ? (
              <p className="text-center text-blue-600 animate-pulse">
                APIを呼び出し中...
              </p>
            ) : error ? (
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
            バックエンド: http://localhost:8080/api/hello
          </p>
        </div>
      </div>
    </main>
  );
}
