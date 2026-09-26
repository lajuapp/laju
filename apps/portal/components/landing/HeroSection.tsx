import Link from 'next/link';
import { ShieldCheck, Download, Zap, Lock, PhoneCall, CheckCircle2 } from 'lucide-react';

export function HeroSection() {
  return (
    <section className="relative pt-24 pb-20 md:pt-32 md:pb-28 overflow-hidden radial-gradient-bg">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center relative z-10">
        {/* Security Badge */}
        <div className="inline-flex items-center gap-2 rounded-full border border-brand-500/30 bg-brand-500/10 px-4 py-1.5 text-xs font-semibold text-brand-400 mb-8 backdrop-blur-md">
          <ShieldCheck className="h-4 w-4" />
          <span>Enkripsi End-to-End Militer • Zero-Knowledge Architecture</span>
        </div>

        {/* Main Headline */}
        <h1 className="text-4xl font-black tracking-tight text-white sm:text-6xl md:text-7xl max-w-4xl mx-auto leading-tight md:leading-tight">
          Komunikasi Cepat & Aman{' '}
          <span className="bg-gradient-to-r from-brand-400 via-emerald-300 to-teal-200 bg-clip-text text-transparent">
            Tanpa Kompromi
          </span>
        </h1>

        {/* Subtitle */}
        <p className="mt-6 text-base sm:text-lg md:text-xl text-slate-300 max-w-2xl mx-auto leading-relaxed font-normal">
          LAJU adalah aplikasi pesan instan dan panggilan suara/video peer-to-peer generasi baru. 
          Bebas penyadapan, bebas pelacak data, dengan kecepatan kilat dan stabilitas tinggi.
        </p>

        {/* CTA Buttons */}
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/download"
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 rounded-2xl bg-brand-500 px-8 py-4 text-sm font-extrabold text-slate-950 shadow-xl shadow-brand-500/25 hover:bg-brand-400 hover:scale-[1.02] transition-all active:scale-95"
          >
            <Download className="h-5 w-5" />
            Unduh LAJU untuk Android (.APK)
          </Link>
          <a
            href="#features"
            className="w-full sm:w-auto flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-8 py-4 text-sm font-bold text-white hover:bg-white/10 transition-all"
          >
            Pelajari Fitur
          </a>
        </div>

        {/* Quick Highlights */}
        <div className="mt-12 flex flex-wrap items-center justify-center gap-6 sm:gap-10 text-xs sm:text-sm text-slate-400 font-medium">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-brand-400" />
            <span>Tanpa Iklan & Pelacak</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-brand-400" />
            <span>Panggilan HD WebRTC P2P</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-brand-400" />
            <span>Grup Hingga Ribuan Anggota</span>
          </div>
        </div>

        {/* Mockup Preview Card */}
        <div className="mt-16 relative mx-auto max-w-4xl">
          <div className="rounded-3xl border border-white/10 bg-slate-900/60 p-4 sm:p-6 shadow-2xl backdrop-blur-xl glow-brand">
            <div className="flex items-center justify-between border-b border-white/10 pb-4 mb-4">
              <div className="flex items-center gap-2">
                <div className="h-3 w-3 rounded-full bg-rose-500/80" />
                <div className="h-3 w-3 rounded-full bg-amber-500/80" />
                <div className="h-3 w-3 rounded-full bg-emerald-500/80" />
              </div>
              <span className="text-xs font-mono text-slate-400">laju-secure-channel://e2ee-connected</span>
              <div className="flex items-center gap-1.5 text-xs text-brand-400 font-semibold">
                <Lock className="h-3 w-3" />
                <span>Enkripsi Aktif</span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-left">
              <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                <div className="flex items-center gap-3 mb-2">
                  <div className="p-2 rounded-xl bg-brand-500/10 text-brand-400">
                    <Zap className="h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white">Ultra Low Latency</h3>
                    <p className="text-xs text-slate-400">Kirim pesan di bawah 50ms</p>
                  </div>
                </div>
              </div>

              <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                <div className="flex items-center gap-3 mb-2">
                  <div className="p-2 rounded-xl bg-emerald-500/10 text-emerald-400">
                    <PhoneCall className="h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white">P2P Audio & Video</h3>
                    <p className="text-xs text-slate-400">Jernih tanpa perantara server</p>
                  </div>
                </div>
              </div>

              <div className="p-4 rounded-2xl bg-white/5 border border-white/5">
                <div className="flex items-center gap-3 mb-2">
                  <div className="p-2 rounded-xl bg-teal-500/10 text-teal-400">
                    <ShieldCheck className="h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white">Privasi Mutlak</h3>
                    <p className="text-xs text-slate-400">Kunci enkripsi di ponsel Anda</p>
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
