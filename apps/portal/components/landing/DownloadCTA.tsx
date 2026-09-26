import Link from 'next/link';
import { Download, Smartphone, ArrowRight, ShieldCheck } from 'lucide-react';

export function DownloadCTA() {
  return (
    <section className="py-20 relative overflow-hidden border-t border-white/5 bg-gradient-to-b from-transparent to-brand-950/20">
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 text-center">
        <div className="rounded-3xl border border-brand-500/20 bg-slate-900/80 p-8 sm:p-14 backdrop-blur-xl relative overflow-hidden shadow-2xl">
          <div className="inline-flex items-center gap-2 rounded-full border border-brand-500/30 bg-brand-500/10 px-4 py-1.5 text-xs font-semibold text-brand-400 mb-6">
            <Smartphone className="h-4 w-4" />
            <span>Mulai Dalam Hitungan Detik</span>
          </div>

          <h2 className="text-3xl sm:text-5xl font-black text-white tracking-tight max-w-2xl mx-auto">
            Ambil Kembali Kendali Penuh Atas Privasi Obrolan Anda
          </h2>

          <p className="mt-4 text-slate-300 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            Unduh aplikasi LAJU sekarang juga di perangkat Android Anda. Bebas biaya pendaftaran dan langsung terhubung dengan aman.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              href="/download"
              className="w-full sm:w-auto flex items-center justify-center gap-3 rounded-2xl bg-brand-500 px-8 py-4 text-sm font-extrabold text-slate-950 shadow-xl shadow-brand-500/20 hover:bg-brand-400 hover:scale-[1.02] transition-all active:scale-95"
            >
              <Download className="h-5 w-5" />
              Unduh APK Android Langsung
            </Link>

            <Link
              href="/privacy"
              className="w-full sm:w-auto flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-6 py-4 text-sm font-semibold text-slate-300 hover:bg-white/10 transition-all"
            >
              <ShieldCheck className="h-4 w-4 text-brand-400" />
              Kebijakan Privasi
            </Link>
          </div>

          <p className="mt-6 text-xs text-slate-400">
            Kompatibel dengan Android 8.0 ke atas. Dukungan iOS dan Desktop segera hadir.
          </p>
        </div>
      </div>
    </section>
  );
}
