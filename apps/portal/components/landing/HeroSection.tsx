import Link from 'next/link';
import { Download, CheckCircle2, ArrowRight, PhoneCall, Sparkles, Zap, Heart, Image as ImageIcon } from 'lucide-react';

export function HeroSection() {
  return (
    <section className="relative pt-16 pb-20 md:pt-24 md:pb-28 overflow-hidden gradient-glow-emerald">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center relative z-10">
        {/* Friendly Top Pill */}
        <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50/90 px-4 py-1.5 text-xs font-bold text-emerald-800 mb-8 shadow-sm">
          <Sparkles className="h-4 w-4 text-emerald-600" />
          <span>Aplikasi Chat & Panggilan Generasi Baru • Ringan & Bebas Iklan</span>
        </div>

        {/* Main Headline */}
        <h1 className="text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-slate-900 max-w-4xl mx-auto leading-[1.15]">
          Chatting Lebih Cepat.{' '}
          <span className="bg-gradient-to-r from-emerald-600 to-teal-600 bg-clip-text text-transparent">
            Bebas Iklan & Nyaman.
          </span>
        </h1>

        {/* Subtitle */}
        <p className="mt-6 text-base sm:text-lg md:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed font-normal">
          Nikmati pengalaman berkirim pesan yang super ringan di HP, hemat kuota baterai, dan jernih untuk teleponan suara maupun video call. Tanpa iklan mengganggu, tanpa spam.
        </p>

        {/* CTA Buttons */}
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/download"
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 rounded-2xl bg-emerald-600 px-8 py-4 text-sm font-bold text-white shadow-lg shadow-emerald-600/25 hover:bg-emerald-700 hover:shadow-emerald-600/35 hover:-translate-y-0.5 transition-all active:translate-y-0"
          >
            <Download className="h-5 w-5" />
            Download Gratis untuk Android
          </Link>
          <a
            href="#features"
            className="w-full sm:w-auto flex items-center justify-center gap-2 rounded-2xl border border-slate-200 bg-white px-7 py-4 text-sm font-bold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-sm"
          >
            Lihat Keunggulan
            <ArrowRight className="h-4 w-4" />
          </a>
        </div>

        {/* Friendly Highlights */}
        <div className="mt-10 flex flex-wrap items-center justify-center gap-6 sm:gap-10 text-xs sm:text-sm text-slate-600 font-semibold">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>100% Gratis Tanpa Langganan</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>Telepon & Video Call Jernih</span>
          </div>
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-4 w-4 text-emerald-600" />
            <span>Ukuran Ringan & Cepat</span>
          </div>
        </div>

        {/* Relatable, Fun Phone Chat Preview */}
        <div className="mt-14 relative mx-auto max-w-2xl">
          {/* Soft background aura */}
          <div className="absolute -inset-4 bg-gradient-to-r from-emerald-100 to-teal-100 rounded-[3rem] blur-2xl opacity-70 -z-10" />

          {/* Clean White Device Frame */}
          <div className="rounded-[2.5rem] border border-slate-200/90 bg-white p-5 sm:p-7 shadow-2xl soft-shadow text-left">
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
                  <div className="text-[11px] text-emerald-600 font-medium">
                    Online • Respon Cepat
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-1.5 text-xs font-semibold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200">
                <Zap className="h-3.5 w-3.5 text-emerald-600" />
                <span>Super Lancar</span>
              </div>
            </div>

            {/* Chat Bubbles */}
            <div className="space-y-4 py-2 text-xs sm:text-sm">
              {/* Message from Contact */}
              <div className="flex items-end gap-2 max-w-[85%]">
                <div className="rounded-2xl rounded-bl-sm bg-slate-100 text-slate-800 p-4 shadow-sm leading-relaxed">
                  <p>Bro, foto dan video liburan kemarin kirim ke sini ya! Jangan lewat chat sebelah, dikompres jadi buram banget 😅</p>
                  <span className="text-[10px] text-slate-500 block mt-1.5">14:20 WIB</span>
                </div>
              </div>

              {/* Message from User */}
              <div className="flex items-end justify-end gap-2 ml-auto max-w-[85%]">
                <div className="rounded-2xl rounded-br-sm bg-emerald-600 text-white p-4 shadow-md shadow-emerald-600/10 leading-relaxed">
                  <p>Siaaap! Di LAJU kirim foto kualitas asli gak bakal pecah sama sekali. Plus gak ada iklan bikin lega banget pakenya 🚀✨</p>
                  <div className="flex items-center justify-end gap-1 mt-1.5 text-[10px] text-emerald-200">
                    <span>14:21 WIB</span>
                    <span>✓✓ Dibaca</span>
                  </div>
                </div>
              </div>

              {/* High-res Photo Sent Mockup */}
              <div className="ml-auto max-w-xs rounded-2xl border border-slate-200 bg-slate-50 p-3 flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-emerald-100 text-emerald-700">
                  <ImageIcon className="h-5 w-5" />
                </div>
                <div className="flex-1 min-w-0 text-xs">
                  <div className="font-bold text-slate-900 truncate">Foto_Pantai_HD.jpg</div>
                  <div className="text-[11px] text-emerald-600 font-medium">8.4 MB • Kualitas Asli Terkirim</div>
                </div>
              </div>

              {/* Voice Call Bar */}
              <div className="mx-auto max-w-md rounded-2xl border border-emerald-200 bg-emerald-50/80 p-3.5 flex items-center justify-between text-xs text-emerald-950 shadow-sm">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-emerald-600 text-white">
                    <PhoneCall className="h-4 w-4" />
                  </div>
                  <div>
                    <div className="font-bold text-slate-900">Panggilan Suara Selesai</div>
                    <div className="text-[11px] text-emerald-700">Durasi 15 menit • Suara HD Bening Tanpa Delay</div>
                  </div>
                </div>
                <span className="text-[11px] font-bold text-emerald-800 bg-white px-2 py-1 rounded-lg border border-emerald-200">
                  Bebas Putus
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
