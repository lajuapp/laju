import { 
  MessageSquare, 
  Clock, 
  ShieldAlert, 
  FileImage, 
  Users, 
  Lock, 
  FileText, 
  Bell, 
  Trash2, 
  Bomb, 
  ShieldCheck, 
  ChevronRight, 
  Paperclip, 
  Mic, 
  Plus,
  Send
} from 'lucide-react';

export function FeaturesSection() {
  return (
    <section id="fitur" className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Two Phones Side-by-Side (Chat & Group Settings) */}
          <div className="lg:col-span-7 flex justify-center items-center gap-4 sm:gap-6 relative">
            
            {/* Phone 1: Chat UI */}
            <div className="w-[260px] sm:w-[290px] rounded-[2.5rem] p-3 bg-slate-900 border-4 border-slate-800 shadow-2xl relative text-left shrink-0">
              <div className="w-full bg-[#121816] rounded-[2rem] pt-4 pb-4 px-3 text-white overflow-hidden text-xs">
                {/* Header */}
                <div className="flex items-center gap-2.5 pb-3 border-b border-white/5">
                  <div className="h-8 w-8 rounded-full bg-gradient-to-tr from-amber-600 to-amber-400 flex items-center justify-center font-bold text-slate-950 text-[10px]">
                    TP
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-bold text-white truncate text-xs">Tim Produk</div>
                    <div className="text-[10px] text-slate-400">3 anggota</div>
                  </div>
                </div>

                {/* E2EE pill */}
                <div className="my-2.5 text-center">
                  <span className="inline-flex items-center gap-1 rounded-full bg-white/5 border border-white/10 px-2.5 py-0.5 text-[9px] text-slate-300">
                    <Lock className="h-2.5 w-2.5 text-emerald-400" />
                    Pesan terenkripsi end-to-end
                  </span>
                </div>

                {/* Chat Bubbles */}
                <div className="space-y-2.5 my-2">
                  <div className="rounded-xl bg-[#1D2522] p-2.5 max-w-[85%] text-[11px] text-slate-200">
                    <p>Udah siap untuk opsi besok?</p>
                    <span className="text-[9px] text-slate-500 block text-right mt-0.5">12:14</span>
                  </div>

                  <div className="rounded-xl bg-[#1D2522] p-2.5 max-w-[85%] text-[11px] text-slate-200 flex items-center gap-2 border border-white/5">
                    <div className="p-1.5 rounded-lg bg-red-500/20 text-red-400">
                      <FileText className="h-3.5 w-3.5" />
                    </div>
                    <div className="flex-1 min-w-0 text-[10px]">
                      <div className="font-bold truncate">Rencana_Produk.pdf</div>
                      <div className="text-slate-400 text-[9px]">2.8 MB • PDF</div>
                    </div>
                    <span className="text-[8px] text-slate-500">12:15</span>
                  </div>

                  <div className="rounded-xl bg-[#0D382C] p-2.5 ml-auto max-w-[85%] text-[11px] text-white">
                    <p>Siap, kita bahas detailnya nanti sore.</p>
                    <span className="text-[8px] text-emerald-300 block text-right mt-0.5">12:16 ✓✓</span>
                  </div>

                  {/* Image Attachment Preview */}
                  <div className="rounded-xl overflow-hidden border border-white/10 max-w-[85%] relative h-24 bg-gradient-to-b from-sky-700 via-teal-800 to-emerald-900 flex items-end p-2">
                    <span className="text-[9px] font-mono bg-black/60 px-1.5 py-0.5 rounded text-white">01:20</span>
                  </div>
                </div>

                {/* Input Bar */}
                <div className="mt-3 pt-2 border-t border-white/5 flex items-center gap-1.5 text-slate-400">
                  <Plus className="h-4 w-4" />
                  <div className="flex-1 bg-white/5 rounded-full px-2.5 py-1 text-[10px] text-slate-400">
                    Ketik pesan
                  </div>
                  <Paperclip className="h-3.5 w-3.5" />
                  <Mic className="h-3.5 w-3.5" />
                  <div className="h-6 w-6 rounded-full bg-[#2DD4BF] text-slate-950 flex items-center justify-center">
                    <Send className="h-3 w-3" />
                  </div>
                </div>
              </div>
            </div>

            {/* Phone 2: Group Settings UI */}
            <div className="w-[260px] sm:w-[290px] rounded-[2.5rem] p-3 bg-slate-900 border-4 border-slate-800 shadow-2xl relative text-left shrink-0 hidden sm:block">
              <div className="w-full bg-[#121816] rounded-[2rem] pt-4 pb-5 px-3 text-white overflow-hidden text-xs">
                {/* Header */}
                <div className="text-center pb-4 border-b border-white/5">
                  <div className="h-14 w-14 rounded-full bg-gradient-to-tr from-amber-600 to-amber-400 mx-auto flex items-center justify-center font-bold text-slate-950 text-base mb-2 shadow-md">
                    TP
                  </div>
                  <div className="font-bold text-white text-sm">Tim Produk</div>
                  <div className="text-[10px] text-slate-400">3 anggota</div>
                </div>

                {/* Settings Rows */}
                <div className="divide-y divide-white/5 text-[11px] text-slate-300">
                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <Bell className="h-3.5 w-3.5 text-slate-400" />
                      <span>Notifikasi</span>
                    </div>
                    <div className="flex items-center gap-1 text-[10px] text-slate-500">
                      <span>Semua pesan</span>
                      <ChevronRight className="h-3 w-3" />
                    </div>
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <Clock className="h-3.5 w-3.5 text-slate-400" />
                      <span>Pesan sementara</span>
                    </div>
                    <div className="flex items-center gap-1 text-[10px] text-emerald-400 font-semibold">
                      <span>7 hari</span>
                      <ChevronRight className="h-3 w-3 text-slate-500" />
                    </div>
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <Trash2 className="h-3.5 w-3.5 text-slate-400" />
                      <span>Kode bersihkan grup</span>
                    </div>
                    <ChevronRight className="h-3 w-3 text-slate-500" />
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <Bomb className="h-3.5 w-3.5 text-rose-400" />
                      <span>Kode hancurkan grup</span>
                    </div>
                    <ChevronRight className="h-3 w-3 text-slate-500" />
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <ShieldCheck className="h-3.5 w-3.5 text-slate-400" />
                      <span>Keamanan</span>
                    </div>
                    <div className="flex items-center gap-1 text-[10px] text-slate-500">
                      <span>Tampilkan perangkat</span>
                      <ChevronRight className="h-3 w-3" />
                    </div>
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <Users className="h-3.5 w-3.5 text-slate-400" />
                      <span>Anggota</span>
                    </div>
                    <div className="flex items-center gap-1 text-[10px] text-slate-500">
                      <span>3 anggota</span>
                      <ChevronRight className="h-3 w-3" />
                    </div>
                  </div>

                  <div className="py-2.5 flex items-center justify-between cursor-pointer hover:text-white">
                    <div className="flex items-center gap-2.5">
                      <FileImage className="h-3.5 w-3.5 text-slate-400" />
                      <span>Media, tautan, dan dokumen</span>
                    </div>
                    <div className="flex items-center gap-1 text-[10px] text-slate-500">
                      <span>532 berkas</span>
                      <ChevronRight className="h-3 w-3" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

          </div>

          {/* Right Column: Feature List */}
          <div className="lg:col-span-5 space-y-8 text-left">
            <div>
              <p className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">
                FITUR UTAMA
              </p>
              <h2 className="text-4xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
                Satu aplikasi<br />
                dengan kendali<br />
                penuh untukmu.
              </h2>
            </div>

            <div className="space-y-6">
              {/* Feature 1 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5">
                  <MessageSquare className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">Pesan pribadi dan grup</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    Ngobrol dengan nyaman bersama orang terdekat.
                  </p>
                </div>
              </div>

              {/* Feature 2 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5">
                  <Clock className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">Pesan sementara</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    Atur pesan agar otomatis hilang sesuai waktu.
                  </p>
                </div>
              </div>

              {/* Feature 3 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5">
                  <ShieldAlert className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">Kode keamanan grup</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    Bersihkan pesan atau hancurkan grup dengan kode khusus.
                  </p>
                </div>
              </div>

              {/* Feature 4 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5">
                  <FileImage className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">Foto, video, dan dokumen</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    Kirim berkas tanpa mengorbankan privasi.
                  </p>
                </div>
              </div>

              {/* Feature 5 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5">
                  <Users className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">Ringan dan cepat</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    Tetap lancar di berbagai kondisi jaringan.
                  </p>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
