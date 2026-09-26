import type { Metadata } from 'next';
import { Download, ShieldCheck, CheckCircle, Info, Hash, FileArchive, ArrowLeft } from 'lucide-react';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Unduh LAJU untuk Android (.APK) | LAJU Secure Messenger',
  description:
    'Download aplikasi LAJU Messenger versi terbaru untuk Android secara langsung. Aman, cepat, dan terenkripsi.',
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
    <div className="py-16 sm:py-24 bg-white gradient-glow-emerald">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>Kembali ke Beranda</span>
        </Link>

        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-4 py-1.5 text-xs font-bold text-emerald-800 mb-6 shadow-sm">
            <Download className="h-4 w-4 text-emerald-600" />
            <span>Versi Resmi v{version} (Stabil)</span>
          </div>

          <h1 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight">
            Unduh Aplikasi LAJU Messenger
          </h1>
          <p className="mt-4 text-slate-600 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            Dapatkan pengalaman komunikasi paling aman dan cepat di ponsel Android Anda langsung dari rilis resmi.
          </p>
        </div>

        {/* Main Clean White Download Box */}
        <div className="rounded-[2.5rem] border border-slate-200/90 bg-white p-8 sm:p-10 shadow-xl soft-shadow relative text-left">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8">
            <div className="flex items-center gap-5">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-emerald-600 text-white font-black text-2xl shadow-lg shadow-emerald-600/25">
                L
              </div>
              <div>
                <h3 className="text-xl font-extrabold text-slate-900">LAJU for Android</h3>
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500 mt-1 font-medium">
                  <span className="font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                    v{version}
                  </span>
                  <span>•</span>
                  {sizeText && (
                    <>
                      <span>{sizeText}</span>
                      <span>•</span>
                    </>
                  )}
                  <span>Android 8.0 ke atas</span>
                  <span>•</span>
                  <span>Format .APK Langsung</span>
                </div>
              </div>
            </div>

            <a
              href={apkDownloadUrl}
              download
              className="w-full md:w-auto flex items-center justify-center gap-3 rounded-2xl bg-emerald-600 px-8 py-4 text-sm font-bold text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 hover:shadow-emerald-600/35 hover:-translate-y-0.5 transition-all active:translate-y-0"
            >
              <Download className="h-5 w-5" />
              Download APK (v{version})
            </a>
          </div>

          {releaseNotes && (
            <div className="mt-6 p-4 rounded-2xl bg-slate-50 border border-slate-200/70 text-xs text-slate-700">
              <span className="font-bold text-slate-900 block mb-1">Catatan Rilis v{version}:</span>
              <p className="whitespace-pre-wrap text-slate-600 leading-relaxed">{releaseNotes}</p>
            </div>
          )}

          {sha256 && (
            <div className="mt-4 p-3.5 rounded-xl bg-slate-50 border border-slate-200/70 text-[11px] font-mono text-slate-600 flex items-center gap-2 overflow-hidden">
              <Hash className="h-3.5 w-3.5 text-emerald-600 shrink-0" />
              <span className="text-slate-400 font-semibold shrink-0">SHA-256:</span>
              <span className="truncate select-all text-slate-700 font-bold">{sha256}</span>
            </div>
          )}

          {/* Quick Security Badges */}
          <div className="mt-8 border-t border-slate-100 pt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-600 font-semibold">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-emerald-600 shrink-0" />
              <span>Bebas Malware & Terverifikasi</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-emerald-600 shrink-0" />
              <span>Rilis Resmi Backoffice</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-emerald-600 shrink-0" />
              <span>Enkripsi End-to-End Bawaan</span>
            </div>
          </div>
        </div>

        {/* Step-by-Step Installation Guide (Clean White Design) */}
        <div className="mt-12 rounded-[2.5rem] border border-slate-200/80 bg-slate-50/70 p-8 sm:p-10 text-left">
          <h3 className="text-lg font-bold text-slate-900 mb-6 flex items-center gap-2">
            <Info className="h-5 w-5 text-emerald-600" />
            Panduan Pemasangan Berkas APK di Android
          </h3>

          <ol className="space-y-5 text-sm text-slate-600 leading-relaxed">
            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white text-xs font-bold">
                1
              </span>
              <div>
                <strong className="text-slate-900">Unduh berkas APK:</strong> Ketuk tombol <em>Download APK</em> di atas dan tunggu hingga unduhan selesai di browser ponsel Anda.
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white text-xs font-bold">
                2
              </span>
              <div>
                <strong className="text-slate-900">Buka berkas unduhan:</strong> Buka panel notifikasi Android atau folder <em>Downloads</em> di manajer berkas perangkat Anda.
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white text-xs font-bold">
                3
              </span>
              <div>
                <strong className="text-slate-900">Izinkan Instalasi dari Sumber Ini:</strong> Jika Android menampilkan peringatan <em>"Install unknown apps"</em>, pilih <strong>Settings / Pengaturan</strong> lalu aktifkan <strong>Allow from this source / Izinkan dari sumber ini</strong>.
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white text-xs font-bold">
                4
              </span>
              <div>
                <strong className="text-slate-900">Pasang & Buka:</strong> Ketuk <strong>Install</strong> dan tunggu beberapa detik hingga proses selesai. Buka aplikasi LAJU dan nikmati obrolan terenkripsi!
              </div>
            </li>
          </ol>
        </div>
      </div>
    </div>
  );
}
