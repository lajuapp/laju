import Link from 'next/link';
import { Smartphone } from 'lucide-react';

export function DownloadCTA() {
  return (
    <section className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Copy & Action Buttons */}
          <div className="lg:col-span-5 space-y-6 text-left">
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
                className="flex items-center gap-2.5 rounded-full bg-[#0D382C] px-7 py-3.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
              >
                <Smartphone className="h-4 w-4" />
                <span>Unduh untuk Android</span>
              </Link>

              <Link
                href="/#fitur"
                className="flex items-center gap-2 rounded-full border border-stone-300 bg-white/80 px-6 py-3.5 text-xs sm:text-sm font-semibold text-slate-800 hover:bg-white hover:text-slate-950 transition-all shadow-sm"
              >
                <span>Pantau pembaruan</span>
              </Link>
            </div>
          </div>

          {/* Right Column: Real Laptop + Smartphone Workspace Photo */}
          <div className="lg:col-span-7 flex justify-center items-center">
            <div className="relative w-full rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white">
              <img
                src="/images/cta-devices.jpg"
                alt="LAJU di Laptop dan Smartphone"
                className="w-full h-auto object-cover transform hover:scale-[1.01] transition-transform duration-500 ease-out"
              />
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
