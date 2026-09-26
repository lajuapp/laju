import type { Metadata } from 'next';
import { Download, ShieldCheck, Smartphone, CheckCircle, Info, Hash, FileArchive } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Unduh LAJU untuk Android (.APK) | LAJU Secure Messenger',
  description:
    'Download aplikasi LAJU Messenger versi terbaru untuk Android secara langsung. Aman, cepat, dan terenkripsi.',
};

async function getLatestAppConfig() {
  try {
    const apiUrl =
      process.env.INTERNAL_API_URL ||
      process.env.NEXT_PUBLIC_API_URL ||
      'http://localhost:3000';

    const res = await fetch(`${apiUrl}/admin/app-config/public`, {
      next: { revalidate: 30 },
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
  const publicApiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.laju.chat';

  const version = config?.latestAndroidVersion || '1.0.0';
  const sizeText = formatFileSize(config?.apkSize);
  const sha256 = config?.apkSha256;
  const releaseNotes = config?.releaseNotes;
  const apkDownloadUrl = config?.apkUrl
    ? `${publicApiUrl}${config.apkUrl}`
    : `${publicApiUrl}/admin/app-config/download-apk`;

  return (
    <div className="py-20 radial-gradient-bg">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-brand-500/30 bg-brand-500/10 px-4 py-1.5 text-xs font-semibold text-brand-400 mb-6">
            <Download className="h-4 w-4" />
            <span>Versi Resmi v{version} (Stabil)</span>
          </div>

          <h1 className="text-3xl sm:text-5xl font-black text-white tracking-tight">
            Unduh Aplikasi LAJU Messenger
          </h1>
          <p className="mt-4 text-slate-300 text-sm sm:text-base max-w-xl mx-auto">
            Dapatkan pengalaman komunikasi paling aman dan cepat di ponsel Android Anda langsung dari rilis resmi.
          </p>
        </div>

        {/* Download Card */}
        <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-8 sm:p-10 backdrop-blur-xl shadow-2xl relative">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8">
            <div className="flex items-center gap-5">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-brand-500 text-slate-950 font-black text-2xl shadow-xl shadow-brand-500/30">
                L
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">LAJU for Android</h3>
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400 mt-1">
                  <span className="font-semibold text-brand-400">v{version}</span>
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
              className="w-full md:w-auto flex items-center justify-center gap-3 rounded-2xl bg-brand-500 px-8 py-4 text-sm font-black text-slate-950 shadow-xl shadow-brand-500/25 hover:bg-brand-400 hover:scale-[1.02] transition-all active:scale-95"
            >
              <Download className="h-5 w-5" />
              Download APK (v{version})
            </a>
          </div>

          {releaseNotes && (
            <div className="mt-6 p-4 rounded-2xl bg-white/[0.03] border border-white/5 text-xs text-slate-300">
              <span className="font-bold text-white block mb-1">Catatan Rilis v{version}:</span>
              <p className="whitespace-pre-wrap text-slate-400">{releaseNotes}</p>
            </div>
          )}

          {sha256 && (
            <div className="mt-4 p-3 rounded-xl bg-black/40 border border-white/5 text-[11px] font-mono text-slate-400 flex items-center gap-2 overflow-hidden">
              <Hash className="h-3.5 w-3.5 text-brand-400 shrink-0" />
              <span className="text-slate-500 font-semibold shrink-0">SHA-256:</span>
              <span className="truncate">{sha256}</span>
            </div>
          )}

          <div className="mt-8 border-t border-white/5 pt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-300">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-brand-400 shrink-0" />
              <span>Bebas Malware & Terverifikasi</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-brand-400 shrink-0" />
              <span>Rilis Resmi Backoffice</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-brand-400 shrink-0" />
              <span>Enkripsi End-to-End Bawaan</span>
            </div>
          </div>
        </div>

        {/* Installation Instructions */}
        <div className="mt-12 rounded-3xl border border-white/5 bg-slate-900/40 p-8">
          <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
            <Info className="h-5 w-5 text-brand-400" />
            Panduan Pemasangan Berkas APK di Android
          </h3>

          <ol className="space-y-4 text-sm text-slate-300 list-decimal list-inside leading-relaxed">
            <li>
              <strong className="text-white">Unduh berkas APK:</strong> Ketuk tombol Download APK di atas dan tunggu hingga unduhan selesai di browser ponsel Anda.
            </li>
            <li>
              <strong className="text-white">Buka berkas unduhan:</strong> Buka panel notifikasi atau folder <em>Downloads</em> di manajer berkas perangkat Anda.
            </li>
            <li>
              <strong className="text-white">Izinkan Instalasi dari Sumber Ini:</strong> Jika Android menampilkan peringatan <em>"Install unknown apps"</em>, pilih <strong>Settings / Pengaturan</strong> lalu aktifkan <strong>Allow from this source / Izinkan dari sumber ini</strong>.
            </li>
            <li>
              <strong className="text-white">Pasang & Buka:</strong> Ketuk <strong>Install</strong> dan tunggu proses selesai. Buka LAJU dan nikmati obrolan yang aman!
            </li>
          </ol>
        </div>
      </div>
    </div>
  );
}
