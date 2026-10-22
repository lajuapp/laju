import type { Metadata } from 'next';
import { DownloadContent } from '@/components/download/DownloadContent';

export const metadata: Metadata = {
  title: 'Unduh LAJU untuk Android (.APK) | LAJU Messenger',
  description:
    'Download aplikasi LAJU Messenger versi terbaru untuk Android. Nikmati obrolan aman, bebas iklan, dan privasi terjaga.',
};

export const dynamic = 'force-dynamic';

async function getLatestAppConfig() {
  try {
    const raw = (process.env.INTERNAL_API_URL || process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000').trim();
    const apiUrl = raw.startsWith('http://') || raw.startsWith('https://') ? raw.replace(/\/+$/, '') : `https://${raw.replace(/\/+$/, '')}`;

    const res = await fetch(`${apiUrl}/admin/app-config/public`, {
      cache: 'no-store',
    });

    if (res.ok) {
      return await res.json();
    }
  } catch (_) {}
  return null;
}

function formatFileSize(bytes?: number | null) {
  if (!bytes) return null;
  const mb = bytes / (1024 * 1024);
  if (mb >= 1) return `${mb.toFixed(1)} MB`;
  const kb = bytes / 1024;
  return `${kb.toFixed(0)} KB`;
}

export default async function DownloadPage() {
  const config = await getLatestAppConfig();
  const rawPublicUrl = (process.env.NEXT_PUBLIC_API_URL || 'https://api.laju.chat').trim();
  const publicApiUrl = rawPublicUrl.startsWith('http://') || rawPublicUrl.startsWith('https://')
    ? rawPublicUrl.replace(/\/+$/, '')
    : `https://${rawPublicUrl.replace(/\/+$/, '')}`;

  const version = config?.latestAndroidVersion || '1.0.0';
  const sizeText = formatFileSize(config?.apkSize);
  const sha256 = config?.apkSha256;
  const releaseNotes = config?.releaseNotes;
  const apkDownloadUrl = config?.apkUrl
    ? `${publicApiUrl}${config.apkUrl}`
    : `${publicApiUrl}/admin/app-config/download-apk`;

  return (
    <DownloadContent
      version={version}
      sizeText={sizeText}
      sha256={sha256}
      releaseNotes={releaseNotes}
      apkDownloadUrl={apkDownloadUrl}
    />
  );
}
