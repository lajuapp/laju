import Link from 'next/link';
import { HelpCircle, Headphones, BookOpen, MessageSquare, ChevronRight, Mail } from 'lucide-react';

export function SupportSection() {
  return (
    <section id="bantuan" className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Headline, Descriptions & Badges */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-100/80 text-emerald-900 text-xs font-bold uppercase tracking-wider">
              <Headphones className="h-3.5 w-3.5 text-emerald-700" />
              <span>Pusat Bantuan & Layanan Pelanggan</span>
            </div>

            <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              Bantuan cepat,<br />
              kapan pun dibutuhkan.
            </h2>

            <p className="text-slate-600 text-base sm:text-lg max-w-xl leading-relaxed font-normal">
              Punya pertanyaan seputar akun, kendala teknis, atau ingin tahu lebih lanjut mengenai enkripsi kami? Tim LAJU dan dokumentasi lengkap kami siap membantu Anda kapan saja.
            </p>

            {/* Support Pillars Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
              <div className="p-4 rounded-2xl bg-white/80 border border-stone-200/80 shadow-xs hover:shadow-md transition-shadow">
                <div className="p-2 w-fit rounded-xl bg-emerald-50 text-[#0D382C] mb-3">
                  <HelpCircle className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-slate-900 text-sm mb-1">Pusat FAQ & Panduan</h3>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Temukan jawaban instan seputar pendaftaran, PIN cadangan, dan fitur pesan sementara.
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-white/80 border border-stone-200/80 shadow-xs hover:shadow-md transition-shadow">
                <div className="p-2 w-fit rounded-xl bg-emerald-50 text-[#0D382C] mb-3">
                  <MessageSquare className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-slate-900 text-sm mb-1">Tiket Dukungan Cepat</h3>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Kirim tiket laporan langsung dari aplikasi dan pantau progres penanganan secara transparan.
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-white/80 border border-stone-200/80 shadow-xs hover:shadow-md transition-shadow">
                <div className="p-2 w-fit rounded-xl bg-emerald-50 text-[#0D382C] mb-3">
                  <BookOpen className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-slate-900 text-sm mb-1">Dokumentasi & Privasi</h3>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Informasi transparan mengenai protokol kriptografi, proteksi metadata, dan hak data pengguna.
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-white/80 border border-stone-200/80 shadow-xs hover:shadow-md transition-shadow">
                <div className="p-2 w-fit rounded-xl bg-emerald-50 text-[#0D382C] mb-3">
                  <Headphones className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-slate-900 text-sm mb-1">Bantuan Tim Khusus</h3>
                <p className="text-xs text-slate-500 leading-relaxed">
                  Tim teknis siaga menindaklanjuti kendala transmisi, pemulihan akun, dan feedback pengguna.
                </p>
              </div>
            </div>

            {/* CTA Button Links */}
            <div className="flex flex-wrap items-center gap-3 pt-4">
              <a
                href="mailto:support@laju.chat"
                className="inline-flex items-center gap-2 rounded-xl bg-[#0D382C] px-6 py-3.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
              >
                <Mail className="h-4 w-4" />
                <span>Hubungi Tim Support</span>
              </a>

              <Link
                href="/terms"
                className="inline-flex items-center gap-1.5 rounded-xl border border-stone-300 bg-white/80 px-5 py-3.5 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-white hover:text-slate-900 transition-all"
              >
                <span>Pelajari Ketentuan & FAQ</span>
                <ChevronRight className="h-4 w-4" />
              </Link>
            </div>
          </div>

          {/* Right Column: User-Uploaded Support Glassmorphic Artwork */}
          <div className="lg:col-span-6">
            <div className="relative mx-auto max-w-lg lg:max-w-none">
              {/* Decorative background glow */}
              <div className="absolute -inset-4 bg-gradient-to-tr from-emerald-500/10 via-teal-500/20 to-transparent rounded-[3rem] blur-2xl -z-10" />

              <div className="relative rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white group">
                <img
                  src="/images/bantuan-support.jpg"
                  alt="Pusat Bantuan dan Layanan Pelanggan LAJU"
                  className="w-full h-auto object-cover transform transition-transform duration-700 group-hover:scale-[1.02]"
                />

                {/* Floating Frosted Overlay Badges on the image */}
                <div className="absolute bottom-5 left-5 right-5 sm:bottom-6 sm:left-6 sm:right-6">
                  <div className="p-3.5 sm:p-4 rounded-2xl bg-slate-900/85 backdrop-blur-md border border-white/15 flex items-center justify-between text-white shadow-xl">
                    <div className="flex items-center gap-3">
                      <div className="p-2 rounded-xl bg-emerald-500/20 text-emerald-400">
                        <Headphones className="h-5 w-5" />
                      </div>
                      <div>
                        <div className="text-xs font-bold sm:text-sm text-white">Layanan Pelanggan Terpadu</div>
                        <div className="text-[11px] text-slate-300">Siap mendengarkan & membantu setiap saat</div>
                      </div>
                    </div>
                    <span className="hidden sm:inline-block px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-300 font-semibold text-[10px] uppercase tracking-wider">
                      Aktif
                    </span>
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
