import Link from 'next/link';
import { Lock, Database, EyeOff, Server, ChevronRight } from 'lucide-react';

export function SecuritySection() {
  return (
    <section id="privasi" className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Copy & Link */}
          <div className="lg:col-span-5 space-y-6 text-left">
            <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">
              KEAMANAN DI SETIAP PESAN
            </p>

            <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              Privasimu,<br />
              itu prioritas.
            </h2>

            <p className="text-slate-600 text-base sm:text-lg max-w-lg leading-relaxed font-normal">
              Semua pesan, panggilan, dan berkas di LAJU dilindungi dengan enkripsi end-to-end. Hanya kamu dan orang yang kamu ajak bicara yang bisa membacanya.
            </p>

            <div className="pt-2">
              <Link
                href="/privacy"
                className="inline-flex items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all"
              >
                <span>Pelajari tentang keamanan</span>
                <ChevronRight className="h-4 w-4" />
              </Link>
            </div>
          </div>

          {/* Right Column: Real Notebook Photo + 4 Dark Cards */}
          <div className="lg:col-span-7 relative">
            <div className="rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 relative min-h-[460px] sm:min-h-[500px] flex items-center justify-end p-5 sm:p-8">
              {/* Background Notebook Photo */}
              <img
                src="/images/security-notebook.jpg"
                alt="LAJU Notebook Keamanan dan Privasi"
                className="absolute inset-0 w-full h-full object-cover object-center"
              />

              {/* Gradient overlay to ensure cards are readable against the photo */}
              <div className="absolute inset-0 bg-gradient-to-r from-transparent via-slate-950/30 to-slate-950/80 pointer-events-none" />

              {/* 4 Sleek Dark Cards */}
              <div className="relative z-10 w-full max-w-xs sm:max-w-sm space-y-3">
                {/* Card 1 */}
                <div className="p-3.5 sm:p-4 rounded-2xl bg-[#121B17]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#121B17] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/10 text-emerald-400 shrink-0">
                    <Lock className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">End-to-end encryption</div>
                    <div className="text-xs text-slate-300">untuk semua pesan</div>
                  </div>
                </div>

                {/* Card 2 */}
                <div className="p-3.5 sm:p-4 rounded-2xl bg-[#121B17]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#121B17] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/10 text-emerald-400 shrink-0">
                    <Database className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Data minim,</div>
                    <div className="text-xs text-slate-300">kendali di tanganmu</div>
                  </div>
                </div>

                {/* Card 3 */}
                <div className="p-3.5 sm:p-4 rounded-2xl bg-[#121B17]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#121B17] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/10 text-emerald-400 shrink-0">
                    <EyeOff className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Tidak ada iklan</div>
                    <div className="text-xs text-slate-300">tidak melacak aktivitas</div>
                  </div>
                </div>

                {/* Card 4 */}
                <div className="p-3.5 sm:p-4 rounded-2xl bg-[#121B17]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#121B17] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/10 text-emerald-400 shrink-0">
                    <Server className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Server dengan standar</div>
                    <div className="text-xs text-slate-300">keamanan modern</div>
                  </div>
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
