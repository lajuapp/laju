import { NextResponse } from 'next/server';

export async function GET() {
  const teamId = process.env.APPLE_TEAM_ID || 'ABCDE12345';
  const bundleId = process.env.APPLE_BUNDLE_ID || 'com.laju.lajuMobile';

  const data = {
    applinks: {
      apps: [],
      details: [
        {
          appID: `${teamId}.${bundleId}`,
          paths: ['/join/*', '/u/*', '/call/*'],
        },
      ],
    },
  };

  return NextResponse.json(data, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=86400, stale-while-revalidate=3600',
    },
  });
}
