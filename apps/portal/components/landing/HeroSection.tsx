import Link from 'next/link';
import { 
  Download, 
  PlayCircle, 
  Lock, 
  Zap, 
  Users, 
  Laptop, 
  Search, 
  MoreVertical, 
  Star, 
  FileText, 
  Image as ImageIcon, 
  Mic, 
  Edit3 
} from 'lucide-react';

export function HeroSection() {
  return (
    <section className="relative pt-8 pb-20 md:pt-14 md:pb-24 overflow-hidden bg-[#F5F4EF]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-8 items-center">
          
          {/* Left Column: Copy & Actions */}
          <div className="lg:col-span-6 space-y-6 text-left">
            {/* Tag */}
            <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">
              PESAN YANG LEBIH TENANG
            </p>

            {/* Title */}
            <h1 className="text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-slate-900 leading-[1.06]">
              Chat, tanpa<br />
              banyak suara.
            </h1>

            {/* Subtitle */}
            <p className="text-slate-600 text-base sm:text-lg max-w-md leading-relaxed font-normal">
              LAJU adalah aplikasi pesan yang fokus pada privasi, keamanan, dan kenyamanan berkumpul dengan orang-orang terdekat.
            </p>

            {/* Buttons */}
            <div className="pt-2 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2.5 rounded-xl bg-[#0D382C] px-6 py-3.5 text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
              >
                <Download className="h-4 w-4" />
                <span>Unduh untuk Android</span>
              </Link>

              <a
                href="#fitur"
                className="flex items-center gap-2 px-4 py-3.5 text-sm font-semibold text-slate-800 hover:text-slate-950 transition-colors"
              >
                <PlayCircle className="h-5 w-5 text-slate-700" />
                <span>Lihat bagaimana</span>
              </a>
            </div>

            {/* 4 Value Props (Horizontal) */}
            <div className="pt-10 grid grid-cols-2 sm:grid-cols-4 gap-6 text-xs text-slate-700">
              <div className="space-y-2">
                <Lock className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  Privasi<br />
                  <span className="font-normal text-slate-600">end-to-end</span>
                </div>
              </div>

              <div className="space-y-2">
                <Zap className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  Ringan<br />
                  <span className="font-normal text-slate-600">dan cepat</span>
                </div>
              </div>

              <div className="space-y-2">
                <Users className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  Grup yang<br />
                  <span className="font-normal text-slate-600">lebih aman</span>
                </div>
              </div>

              <div className="space-y-2">
                <Laptop className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  Lintas perangkat<br />
                  <span className="font-normal text-slate-600">dengan kendali penuh</span>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Phone Mockup held in atmosphere */}
          <div className="lg:col-span-6 flex justify-center lg:justify-end relative">
            {/* Ambient desk background circle */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[380px] sm:w-[480px] h-[380px] sm:h-[480px] rounded-full bg-[#EAE8DE]/70 -z-10 blur-xl" />

            {/* Phone Frame */}
            <div className="w-[310px] sm:w-[340px] rounded-[3rem] p-3.5 bg-slate-900 border-[6px] border-slate-800 shadow-2xl relative text-left">
              {/* Speaker / Dynamic notch */}
              <div className="absolute top-6 left-1/2 -translate-x-1/2 w-24 h-4 bg-slate-950 rounded-full z-20 flex items-center justify-center">
                <div className="w-3 h-3 rounded-full bg-slate-900 ml-auto mr-1.5" />
              </div>

              {/* Inner Screen */}
              <div className="w-full bg-[#121816] rounded-[2.5rem] pt-6 pb-6 px-4 text-white overflow-hidden relative shadow-inner">
                {/* Status Bar */}
                <div className="flex items-center justify-between text-[11px] font-semibold text-slate-400 px-2 pt-1 mb-4">
                  <span>8:41</span>
                  <div className="flex items-center gap-1.5">
                    <span>5G</span>
                    <div className="w-4 h-2 rounded-sm border border-slate-400 p-0.5">
                      <div className="w-full h-full bg-slate-300" />
                    </div>
                  </div>
                </div>

                {/* App Header */}
                <div className="flex items-center justify-between pb-4 border-b border-white/5 px-2">
                  <span className="text-xl font-black tracking-tight text-white font-sans">
                    LAJU
                  </span>
                  <div className="flex items-center gap-3 text-slate-400">
                    <Search className="h-4 w-4 cursor-pointer hover:text-white" />
                    <MoreVertical className="h-4 w-4 cursor-pointer hover:text-white" />
                  </div>
                </div>

                {/* Chat List Items */}
                <div className="mt-3 space-y-3.5">
                  {/* Item 1: Tim Produk (Starred) */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-amber-600 to-amber-400 flex items-center justify-center text-xs font-bold text-slate-950 shrink-0 shadow-sm">
                      TP
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-1.5">
                          <span className="text-sm font-bold text-white truncate">Tim Produk</span>
                          <Star className="h-3 w-3 fill-amber-400 text-amber-400 shrink-0" />
                        </div>
                        <span className="text-[10px] text-slate-400 font-medium">10:24</span>
                      </div>
                      <p className="text-xs text-slate-400 truncate mt-0.5">
                        Diskusi desain untuk rilis berikutny...
                      </p>
                    </div>
                  </div>

                  {/* Item 2: Raka */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-blue-600 to-cyan-500 flex items-center justify-center text-xs font-bold text-white shrink-0">
                      R
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-white truncate">Raka</span>
                        <span className="text-[10px] text-slate-400 font-medium">09:41</span>
                      </div>
                      <div className="flex items-center gap-1 text-xs text-slate-400 truncate mt-0.5">
                        <FileText className="h-3 w-3 text-emerald-400 shrink-0" />
                        <span className="truncate">file: rencana.pdf</span>
                      </div>
                    </div>
                  </div>

                  {/* Item 3: Nadin */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-purple-600 to-pink-500 flex items-center justify-center text-xs font-bold text-white shrink-0">
                      N
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-white truncate">Nadin</span>
                        <span className="text-[10px] text-slate-400 font-medium">Kemarin</span>
                      </div>
                      <p className="text-xs text-slate-400 truncate mt-0.5">
                        Siap, nanti aku cek lagi
                      </p>
                    </div>
                  </div>

                  {/* Item 4: Keluarga */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-emerald-600 to-teal-400 flex items-center justify-center text-xs font-bold text-slate-950 shrink-0">
                      K
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-white truncate">Keluarga</span>
                        <span className="text-[10px] text-slate-400 font-medium">Kemarin</span>
                      </div>
                      <div className="flex items-center gap-1 text-xs text-slate-400 truncate mt-0.5">
                        <ImageIcon className="h-3 w-3 text-cyan-400 shrink-0" />
                        <span>Foto</span>
                      </div>
                    </div>
                  </div>

                  {/* Item 5: Andi */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-rose-600 to-orange-400 flex items-center justify-center text-xs font-bold text-white shrink-0">
                      A
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-white truncate">Andi</span>
                        <span className="text-[10px] text-slate-400 font-medium">21:05</span>
                      </div>
                      <div className="flex items-center gap-1 text-xs text-slate-400 truncate mt-0.5">
                        <Mic className="h-3 w-3 text-emerald-400 shrink-0" />
                        <span>Voice message</span>
                      </div>
                    </div>
                  </div>

                  {/* Item 6: Projek Danau */}
                  <div className="flex items-center gap-3 p-1.5 rounded-xl hover:bg-white/5 transition-colors cursor-pointer">
                    <div className="h-11 w-11 rounded-full bg-gradient-to-tr from-teal-700 to-emerald-500 flex items-center justify-center text-xs font-bold text-white shrink-0">
                      PD
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-white truncate">Projek Danau</span>
                        <span className="text-[10px] text-slate-400 font-medium">20:10</span>
                      </div>
                      <p className="text-xs text-slate-400 truncate mt-0.5">
                        Oke, makasih semua!
                      </p>
                    </div>
                  </div>
                </div>

                {/* Floating Action Button (FAB) */}
                <div className="absolute bottom-6 right-5 h-12 w-12 rounded-2xl bg-[#2DD4BF] text-slate-950 flex items-center justify-center shadow-lg shadow-teal-500/30 cursor-pointer hover:scale-105 transition-transform">
                  <Edit3 className="h-5 w-5" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
