import { ArrowLeft, Check } from 'lucide-react';

export function DisappearingMessagesSection() {
  return (
    <section className="py-20 sm:py-28 bg-[#18262E] text-white relative overflow-hidden">
      {/* Background twilight gradient effect */}
      <div className="absolute inset-0 bg-gradient-to-r from-[#141F26] via-[#1A2E35] to-[#253D3A] opacity-90 -z-10" />
      <div className="absolute -top-32 right-0 w-[500px] h-[500px] bg-amber-500/10 rounded-full blur-3xl -z-10" />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <p className="text-xs font-bold text-emerald-400/80 uppercase tracking-widest">
              LEBIH DARI SEKEDAR CHAT
            </p>

            <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white tracking-tight leading-[1.08]">
              Ruang yang<br />
              tetap terjaga.
            </h2>

            <p className="text-slate-300 text-base sm:text-lg max-w-lg leading-relaxed font-normal">
              Dari obrolan sehari-hari sampai diskusi penting. LAJU hadir sebagai ruang yang lebih tenang, aman, dan bebas distraksi.
            </p>
          </div>

          {/* Right Column: Phone showing Disappearing Messages settings */}
          <div className="lg:col-span-6 flex justify-center lg:justify-end">
            <div className="w-[280px] sm:w-[310px] rounded-[2.8rem] p-3.5 bg-slate-900 border-4 border-slate-700 shadow-2xl relative text-left">
              <div className="w-full bg-[#121816] rounded-[2.2rem] pt-5 pb-7 px-4 text-white overflow-hidden text-xs">
                {/* Header */}
                <div className="flex items-center gap-3 pb-4 mb-4 border-b border-white/5">
                  <ArrowLeft className="h-4 w-4 text-slate-400 cursor-pointer" />
                  <span className="font-bold text-sm text-white">Pesan sementara</span>
                </div>

                {/* Radio Options List */}
                <div className="space-y-4 pt-1 text-xs">
                  {/* Mati */}
                  <div className="flex items-center justify-between p-2 rounded-xl hover:bg-white/5 cursor-pointer">
                    <span className="text-slate-300">Mati</span>
                    <div className="h-4 w-4 rounded-full border border-slate-500" />
                  </div>

                  {/* 24 jam */}
                  <div className="flex items-center justify-between p-2 rounded-xl hover:bg-white/5 cursor-pointer">
                    <span className="text-slate-300">24 jam</span>
                    <div className="h-4 w-4 rounded-full border border-slate-500" />
                  </div>

                  {/* 7 hari (Selected) */}
                  <div className="flex items-center justify-between p-2 rounded-xl bg-white/5 border border-emerald-500/20 cursor-pointer">
                    <span className="text-emerald-400 font-semibold">7 hari</span>
                    <div className="h-4 w-4 rounded-full bg-emerald-500 flex items-center justify-center">
                      <div className="h-1.5 w-1.5 rounded-full bg-slate-950" />
                    </div>
                  </div>

                  {/* 30 hari */}
                  <div className="flex items-center justify-between p-2 rounded-xl hover:bg-white/5 cursor-pointer">
                    <span className="text-slate-300">30 hari</span>
                    <div className="h-4 w-4 rounded-full border border-slate-500" />
                  </div>

                  {/* 90 hari */}
                  <div className="flex items-center justify-between p-2 rounded-xl hover:bg-white/5 cursor-pointer">
                    <span className="text-slate-300">90 hari</span>
                    <div className="h-4 w-4 rounded-full border border-slate-500" />
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
