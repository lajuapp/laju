import Link from 'next/link';
import { Smartphone, Download, ArrowUpRight } from 'lucide-react';

export function DownloadCTA() {
  return (
    <section className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          
          {/* Left Column */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">
              UNDUH SEKARANG
            </p>

            <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              Mulai percakapan<br />
              yang lebih aman.
            </h2>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal">
              Tersedia untuk Android.<br />
              Versi lainnya segera hadir.
            </p>

            {/* Buttons */}
            <div className="pt-2 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2.5 rounded-xl bg-[#0D382C] px-6 py-3.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
              >
                <Smartphone className="h-4 w-4" />
                <span>Unduh untuk Android</span>
              </Link>

              <Link
                href="/#fitur"
                className="flex items-center gap-2 rounded-xl border border-slate-300 bg-white/70 px-5 py-3.5 text-xs sm:text-sm font-semibold text-slate-800 hover:bg-white hover:text-slate-950 transition-all shadow-sm"
              >
                <span>Pantau pembaruan</span>
              </Link>
            </div>
          </div>

          {/* Right Column: Lifestyle Morning Coffee Setting Graphic */}
          <div className="lg:col-span-6 flex justify-center lg:justify-end">
            <div className="w-full max-w-md rounded-3xl overflow-hidden border border-[#EAE8DE] bg-[#EBE9DF] p-8 shadow-sm text-left relative">
              <div className="space-y-4">
                <div className="inline-flex items-center gap-2 text-xs font-bold text-[#0D382C] bg-white/80 px-3 py-1 rounded-full border border-[#0D382C]/10">
                  <span>LAJU Mobile v1.0.0</span>
                </div>
                <h3 className="text-2xl font-bold text-slate-900 leading-snug">
                  Ruang yang Lebih Tenang di Ponselmu
                </h3>
                <p className="text-sm text-slate-600 leading-relaxed">
                  Tidak ada notifikasi spam, tidak ada algoritma rekomendasi yang menyita waktu. Hanya ruang bersih untuk orang-orang terdekatmu.
                </p>
                <div className="pt-4 flex items-center gap-4 text-xs font-semibold text-slate-700">
                  <span className="flex items-center gap-1.5">
                    <span className="h-2 w-2 rounded-full bg-emerald-500" />
                    Android 8.0+
                  </span>
                  <span>•</span>
                  <span>Format .APK Langsung</span>
                  <span>•</span>
                  <span>Bebas Iklan</span>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
