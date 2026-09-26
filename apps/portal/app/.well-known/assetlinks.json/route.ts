import { NextResponse } from 'next/server';

export async function GET() {
  const sha256Fingerprints = process.env.ANDROID_SHA256_FINGERPRINTS
    ? process.env.ANDROID_SHA256_FINGERPRINTS.split(',').map((s) => s.trim())
    : [
        // Default debug keystore fingerprint or placeholder
        'FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C'
      ];

  const data = [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: 'com.laju.laju_mobile',
        sha256_cert_fingerprints: sha256Fingerprints,
      },
    },
  ];

  return NextResponse.json(data, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=86400, stale-while-revalidate=3600',
    },
  });
}
