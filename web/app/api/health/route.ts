import { NextResponse } from 'next/server';

/**
 * Health Check Endpoint
 * 
 * ALB が定期的にヘルスチェックを実行するためのエンドポイント
 * 
 * @returns {Object} ヘルスステータス
 * 
 * @example
 * GET /api/health
 * Response: { "status": "healthy" }
 */
export async function GET() {
  return NextResponse.json(
    {
      status: 'healthy',
      timestamp: new Date().toISOString(),
    },
    { status: 200 }
  );
}
