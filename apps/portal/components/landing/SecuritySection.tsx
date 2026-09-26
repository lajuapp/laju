import Link from 'next/link';
import { Lock, Database, EyeOff, Server, ChevronRight } from 'lucide-react';

export function SecuritySection() {
  return (
    <section id="privasi" className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column */}
          <div className="lg:col-span-6 space-y-6 text-left">
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
                className="inline-flex items-center gap-2 rounded-xl bg-[#0D382C] px-6 py-3.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all"
              >
                <span>Pelajari tentang keamanan</span>
                <ChevronRight className="h-4 w-4" />
              </Link>
            </div>
          </div>

          {/* Right Column: Leather Notebook Aesthetic & 4 Dark Cards */}
          <div className="lg:col-span-6 relative">
            {/* Visual Container */}
            <div className="rounded-[2.5rem] bg-[#121B17] p-6 sm:p-8 relative overflow-hidden shadow-2xl border border-white/5">
              
              {/* Embossed Notebook & Plant Accent Header */}
              <div className="flex items-center justify-between pb-6 mb-6 border-b border-white/10 text-white">
                <div className="flex items-center gap-3">
                  <div className="h-9 w-9 rounded-xl bg-white/10 flex items-center justify-center font-black text-sm tracking-wider">
                    L
                  </div>
                  <span className="font-bold text-sm tracking-wide text-emerald-400">LAJU SECURE PROTOCOL</span>
                </div>
                <span className="text-[10px] font-mono text-slate-400">ZERO-KNOWLEDGE</span>
              </div>

              {/* 4 Sleek Dark Cards */}
              <div className="space-y-3">
                {/* Card 1 */}
                <div className="p-4 rounded-2xl bg-white/[0.04] border border-white/5 flex items-center gap-4 text-left hover:bg-white/[0.07] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/5 text-emerald-400 shrink-0">
                    <Lock className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">End-to-end encryption</div>
                    <div className="text-xs text-slate-400">untuk semua pesan</div>
                  </div>
                </div>

                {/* Card 2 */}
                <div className="p-4 rounded-2xl bg-white/[0.04] border border-white/5 flex items-center gap-4 text-left hover:bg-white/[0.07] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/5 text-emerald-400 shrink-0">
                    <Database className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Data minim,</div>
                    <div className="text-xs text-slate-400">kendali di tanganmu</div>
                  </div>
                </div>

                {/* Card 3 */}
                <div className="p-4 rounded-2xl bg-white/[0.04] border border-white/5 flex items-center gap-4 text-left hover:bg-white/[0.07] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/5 text-emerald-400 shrink-0">
                    <EyeOff className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Tidak ada iklan</div>
                    <div className="text-xs text-slate-400">tidak melacak aktivitas</div>
                  </div>
                </div>

                {/* Card 4 */}
                <div className="p-4 rounded-2xl bg-white/[0.04] border border-white/5 flex items-center gap-4 text-left hover:bg-white/[0.07] transition-colors">
                  <div className="p-2.5 rounded-xl bg-white/5 text-emerald-400 shrink-0">
                    <Server className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">Server dengan standar</div>
                    <div className="text-xs text-slate-400">keamanan modern</div>
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
