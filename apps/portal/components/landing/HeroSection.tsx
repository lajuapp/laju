import Link from 'next/link';
import { ShieldCheck, Download, Lock, CheckCircle2, ArrowRight, PhoneCall, Sparkles } from 'lucide-react';

export function HeroSection() {
  return (
    <section className="relative pt-16 pb-20 md:pt-24 md:pb-28 overflow-hidden gradient-glow-emerald">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center relative z-10">
        {/* Security Badge */}
        <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50/80 px-4 py-1.5 text-xs font-bold text-emerald-800 mb-8 shadow-sm">
          <ShieldCheck className="h-4 w-4 text-emerald-600" />
          <span>Arsitektur Zero-Knowledge • Enkripsi End-to-End Sejati</span>
        </div>

        {/* Main Headline */}
        <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-slate-900 max-w-4xl mx-auto leading-[1.15]">
          Pesan & Panggilan Suara/Video.{' '}
          <span className="bg-gradient-to-r from-emerald-600 to-teal-600 bg-clip-text text-transparent">
            Tanpa Jejak.
          </span>
        </h1>

        {/* Subtitle */}
        <p className="mt-6 text-base sm:text-lg md:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed font-normal">
          LAJU adalah aplikasi pesan instan dan panggilan peer-to-peer generasi baru. 
          Kunci enkripsi dibuat langsung di perangkat Anda—bebas iklan, bebas pelacak data, dan terlindungi dari segala bentuk penyadapan.
        </p>

        {/* CTA Buttons */}
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/download"
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 rounded-2xl bg-emerald-600 px-8 py-4 text-sm font-bold text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 hover:shadow-emerald-600/35 hover:-translate-y-0.5 transition-all active:translate-y-0"
          >
            <Download className="h-5 w-5" />
            Unduh APK Android Resmi
          </Link>
          <a
            href="#features"
            className="w-full sm:w-auto flex items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-7 py-4 text-sm font-bold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-sm"
          >
            Pelajari Cara Kerja
            <ArrowRight className="h-4 w-4" />
          </a>
        </div>

        {/* Quick Trust Highlights */}
        <div className="mt-10 flex flex-wrap items-center justify-center gap-6 sm:gap-10 text-xs sm:text-sm text-slate-600 font-semibold">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>Tanpa Iklan & Pelacak</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>Panggilan P2P WebRTC Direct</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>Bebas Sensor & Mandiri</span>
          </div>
        </div>

        {/* Live Product Visual Showcase (No generic dark cards) */}
        <div className="mt-14 relative mx-auto max-w-3xl">
          {/* Subtle surrounding glow */}
          <div className="absolute -inset-4 bg-gradient-to-r from-emerald-100 to-teal-100 rounded-[3rem] blur-2xl opacity-70 -z-10" />

          {/* Clean White Device Frame */}
          <div className="rounded-[2.5rem] border border-slate-200/80 bg-white p-4 sm:p-7 shadow-2xl soft-shadow text-left">
            {/* Top Bar */}
            <div className="flex items-center justify-between border-b border-slate-100 pb-4 mb-5">
              <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-full bg-emerald-100 text-emerald-800 font-bold flex items-center justify-center text-sm shadow-inner">
                  AR
                </div>
                <div>
                  <div className="flex items-center gap-1.5 text-sm font-bold text-slate-900">
                    <span>Ahmad Rasyid</span>
                    <span className="h-2 w-2 rounded-full bg-emerald-500" />
                  </div>
                  <div className="flex items-center gap-1 text-[11px] text-emerald-700 font-medium">
                    <Lock className="h-3 w-3" />
                    <span>Enkripsi End-to-End Aktif</span>
                  </div>
                </div>
              </div>

              <div className="hidden sm:flex items-center gap-2 rounded-full bg-slate-50 border border-slate-200/70 px-3 py-1 text-[11px] font-mono font-medium text-slate-600">
                <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                <span>P2P Direct • 18ms</span>
              </div>
            </div>

            {/* Simulated Chat Flow */}
            <div className="space-y-4 py-2 text-xs sm:text-sm">
              {/* Message from Contact */}
              <div className="flex items-end gap-2 max-w-[85%]">
                <div className="rounded-2xl rounded-bl-sm bg-slate-100 text-slate-800 p-4 shadow-sm leading-relaxed">
                  <p>Bro, obrolan ini aman kan dari penyadapan provider atau pihak ketiga?</p>
                  <span className="text-[10px] text-slate-500 block mt-1">10:42 WIB</span>
                </div>
              </div>

              {/* Message from User */}
              <div className="flex items-end justify-end gap-2 ml-auto max-w-[85%]">
                <div className="rounded-2xl rounded-br-sm bg-emerald-600 text-white p-4 shadow-md shadow-emerald-600/10 leading-relaxed">
                  <p>100% aman! Kunci enkripsi dibuat langsung di HP kita via Double Ratchet. Server LAJU pun gak bisa baca atau simpan riwayatnya 🔒🚀</p>
                  <div className="flex items-center justify-end gap-1 mt-1 text-[10px] text-emerald-200">
                    <span>10:43 WIB</span>
                    <span>✓✓</span>
                  </div>
                </div>
              </div>

              {/* P2P Voice Call Notification Pill */}
              <div className="mx-auto max-w-md rounded-2xl border border-emerald-200 bg-emerald-50/70 p-3.5 flex items-center justify-between text-xs text-emerald-900 shadow-sm">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-emerald-600 text-white">
                    <PhoneCall className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="font-bold">Panggilan Suara Terenkripsi Selesai</div>
                    <div className="text-[11px] text-emerald-700">Durasi 12m 45s • Audio HD Opus P2P</div>
                  </div>
                </div>
                <span className="font-mono text-[10px] font-bold bg-white text-emerald-800 px-2 py-1 rounded-lg border border-emerald-200">
                  Bitrate Stabil
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
