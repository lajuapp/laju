import type { Metadata } from 'next';
import { DownloadContent } from '@/components/download/DownloadContent';

export const metadata: Metadata = {
  title: 'Unduh LAJU Messenger | Resmi di Google Play & App Store',
  description:
    'Download aplikasi LAJU Messenger versi terbaru resmi dari Google Play Store dan Apple App Store. Nikmati obrolan aman, bebas iklan, dan privasi terjaga tanpa nomor telepon.',
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

function resolvePlayStoreWebUrl(rawUrl?: string | null): string {
  const defaultUrl = 'https://play.google.com/store/apps/details?id=com.laju.mobile';
  if (!rawUrl || !rawUrl.trim()) return defaultUrl;

  const trimmed = rawUrl.trim();
  if (trimmed.startsWith('market://details?id=')) {
    const pkg = trimmed.replace('market://details?id=', '').split('&')[0];
    return `https://play.google.com/store/apps/details?id=${pkg}`;
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return defaultUrl;
}

function resolveAppStoreWebUrl(rawUrl?: string | null): string {
  const defaultUrl = 'https://apps.apple.com/app/laju/id6740000000';
  if (!rawUrl || !rawUrl.trim()) return defaultUrl;

  const trimmed = rawUrl.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return defaultUrl;
}

export default async function DownloadPage() {
  const config = await getLatestAppConfig();

  const androidVersion = config?.latestAndroidVersion || '1.0.0';
  const iosVersion = config?.latestIosVersion || config?.latestAndroidVersion || '1.0.0';
  const releaseNotes = config?.releaseNotes;
  const playStoreUrl = resolvePlayStoreWebUrl(config?.playStoreUrl);
  const appStoreUrl = resolveAppStoreWebUrl(config?.appStoreUrl);

  return (
    <DownloadContent
      androidVersion={androidVersion}
      iosVersion={iosVersion}
      playStoreUrl={playStoreUrl}
      appStoreUrl={appStoreUrl}
      releaseNotes={releaseNotes}
    />
  );
}
