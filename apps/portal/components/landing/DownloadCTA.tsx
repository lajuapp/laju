import Link from 'next/link';
import { Download, Smartphone, Sparkles, ArrowRight } from 'lucide-react';

export function DownloadCTA() {
  return (
    <section className="py-20 bg-slate-50/50 border-t border-slate-100 relative overflow-hidden">
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 text-center">
        {/* Clean White Card */}
        <div className="rounded-[2.5rem] border border-emerald-100 bg-white p-8 sm:p-14 shadow-xl soft-shadow relative overflow-hidden">
          {/* Soft background aura */}
          <div className="absolute top-0 right-0 -mt-12 -mr-12 w-96 h-96 bg-emerald-50 rounded-full blur-3xl -z-10" />

          <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-4 py-1.5 text-xs font-bold text-emerald-800 mb-6 shadow-sm">
            <Sparkles className="h-4 w-4 text-emerald-600" />
            <span>Mulai Dalam Hitungan Detik</span>
          </div>

          <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight max-w-2xl mx-auto leading-tight">
            Yuk, Coba Obrolan yang Lebih Nyaman Hari Ini!
          </h2>

          <p className="mt-4 text-slate-600 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            Download LAJU secara gratis di HP Android kamu. Nikmati obrolan cepat, telepon jernih, dan ketenangan tanpa iklan mengganggu.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              href="/download"
              className="w-full sm:w-auto flex items-center justify-center gap-3 rounded-2xl bg-emerald-600 px-8 py-4 text-sm font-bold text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 hover:shadow-emerald-600/35 hover:-translate-y-0.5 transition-all active:translate-y-0"
            >
              <Download className="h-5 w-5" />
              Download APK Sekarang (Gratis)
            </Link>

            <a
              href="#features"
              className="w-full sm:w-auto flex items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-6 py-4 text-sm font-semibold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-sm"
            >
              Lihat Keunggulan
              <ArrowRight className="h-4 w-4" />
            </a>
          </div>

          <p className="mt-6 text-xs text-slate-400 font-medium">
            Kompatibel dengan semua HP Android 8.0 ke atas • Instalasi Mudah & Cepat
          </p>
        </div>
      </div>
    </section>
  );
}
