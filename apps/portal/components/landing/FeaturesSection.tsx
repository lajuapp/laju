import { 
  Zap, 
  PhoneCall, 
  ShieldCheck, 
  Sparkles, 
  Ban, 
  Users, 
  Image as ImageIcon, 
  CheckCircle2,
  Heart,
  Smile,
  Send
} from 'lucide-react';

export function FeaturesSection() {
  return (
    <section id="features" className="py-20 sm:py-28 bg-slate-50/60 border-t border-slate-100 relative">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-800 bg-emerald-100/70 border border-emerald-200/80 px-3.5 py-1 rounded-full uppercase tracking-wider mb-4">
            <Sparkles className="h-3.5 w-3.5 text-emerald-600" />
            <span>Kenyamanan Nomor Satu</span>
          </div>
          <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
            Semua yang Kamu Butuhkan dari Aplikasi Chat,{' '}
            <span className="text-emerald-600">Dibuat Lebih Baik.</span>
          </h2>
          <p className="mt-4 text-slate-600 text-base sm:text-lg leading-relaxed">
            Tidak ada lagi aplikasi chat yang lambat, makan banyak memori, atau dipenuhi iklan mengganggu. LAJU dirancang khusus agar komunikasi harianmu terasa menyenangkan.
          </p>
        </div>

        {/* Feature Highlight 1: Kecepatan & Ringan di HP */}
        <div className="mb-20 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-6 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 text-xs font-bold text-emerald-800 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200">
              <Zap className="h-4 w-4 text-emerald-600" />
              <span>Buka Seketika, Langsung Siap</span>
            </div>
            <h3 className="text-2xl sm:text-4xl font-extrabold text-slate-900 leading-snug">
              Super Cepat & Gak Bikin HP Lemot
            </h3>
            <p className="text-slate-600 text-sm sm:text-base leading-relaxed">
              Pernah merasa aplikasi chat lama banget saat dibuka atau bikin HP panas? LAJU dirancang dengan ukuran yang sangat ringkas dan efisien. Pesan masuk dan terkirim seketika, bahkan saat sinyal kamu hanya 1 bar.
            </p>

            <div className="space-y-3 pt-2 text-sm text-slate-700 font-semibold">
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Ukuran aplikasi hemat penyimpanan memori HP</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Konsumsi baterai sangat minim meski aktif seharian</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Notifikasi panggilan & pesan selalu masuk tepat waktu</span>
              </div>
            </div>
          </div>

          <div className="lg:col-span-6">
            <div className="rounded-3xl border border-slate-200 bg-white p-6 sm:p-8 shadow-xl soft-shadow text-left">
              <div className="flex items-center justify-between mb-6 pb-4 border-b border-slate-100">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-2xl bg-emerald-600 text-white flex items-center justify-center font-bold">
                    <Send className="h-5 w-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-900">Performa Transmisi Kilat</h4>
                    <p className="text-xs text-slate-500">Hemat Kuota Internet</p>
                  </div>
                </div>
                <span className="text-xs font-bold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200">
                  Responsif
                </span>
              </div>

              <div className="space-y-3 text-xs">
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-center justify-between">
                  <span className="text-slate-600 font-medium">Waktu Buka Aplikasi:</span>
                  <span className="font-bold text-emerald-600 bg-white px-2.5 py-1 rounded-md border border-slate-200">
                    Instan (Kurang dari 1 Detik)
                  </span>
                </div>
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-center justify-between">
                  <span className="text-slate-600 font-medium">Beban RAM & Memori:</span>
                  <span className="font-bold text-slate-800 bg-white px-2.5 py-1 rounded-md border border-slate-200">
                    Hingga 60% Lebih Ringan
                  </span>
                </div>
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/80 flex items-center justify-between">
                  <span className="text-slate-600 font-medium">Penggunaan Kuota:</span>
                  <span className="font-bold text-emerald-700 bg-white px-2.5 py-1 rounded-md border border-slate-200">
                    Kompresi Cerdas & Efisien
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Feature Highlight 2: Panggilan Bening & Bebas Iklan */}
        <div className="mb-20 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-6 order-2 lg:order-1">
            <div className="rounded-3xl border border-slate-200 bg-white p-6 sm:p-8 shadow-xl soft-shadow text-left">
              <div className="flex items-center justify-between mb-6 pb-4 border-b border-slate-100">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-2xl bg-emerald-600 text-white flex items-center justify-center font-bold">
                    <PhoneCall className="h-5 w-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-900">Panggilan Suara & Video HD</h4>
                    <p className="text-xs text-slate-500">Audio Jernih Tanpa Delay</p>
                  </div>
                </div>
                <span className="text-xs font-bold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200">
                  Kualitas Suara Bening
                </span>
              </div>

              <div className="space-y-4">
                <div className="p-4 rounded-2xl bg-emerald-50/70 border border-emerald-200 text-xs text-emerald-950">
                  <div className="font-bold text-emerald-900 mb-1 flex items-center gap-1.5">
                    <Heart className="h-4 w-4 text-emerald-600" />
                    <span>Teleponan Lama Tetap Nyaman</span>
                  </div>
                  <p className="text-slate-600 leading-relaxed">
                    Koneksi telepon langsung menghubungkan ponselmu dengan rekan bicara tanpa muter lewat server jauh, jadi suara terdengar jelas seperti mengobrol berhadapan.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center justify-between">
                  <span className="font-medium">Video Call HD Tanpa Patah-patah</span>
                  <span className="font-bold text-emerald-600 bg-white px-2.5 py-1 rounded-md border border-slate-200">
                    Resolusi Otomatis Menyesuaikan Sinyal
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div className="lg:col-span-6 order-1 lg:order-2 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 text-xs font-bold text-emerald-800 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200">
              <PhoneCall className="h-4 w-4 text-emerald-600" />
              <span>Teleponan Puas Tanpa Batas</span>
            </div>
            <h3 className="text-2xl sm:text-4xl font-extrabold text-slate-900 leading-snug">
              Panggilan Jernih, Bebas Delay & Tanpa Iklan
            </h3>
            <p className="text-slate-600 text-sm sm:text-base leading-relaxed">
              Bosan dengan aplikasi yang menampilkan banner iklan saat sedang asyik chat? Di LAJU, tampilan bersih 100% didedikasikan untuk kamu dan orang-orang terdekatmu.
            </p>

            <div className="space-y-3 pt-2 text-sm text-slate-700 font-semibold">
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Nol Iklan Mengganggu, Nol Banner Promosi</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Kirim foto & video dalam kualitas asli tanpa dikompres pecah</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-5 w-5 text-emerald-600 shrink-0" />
                <span>Grup obrolan keluarga, hobi, dan kerjaan tanpa batasan kuota</span>
              </div>
            </div>
          </div>
        </div>

        {/* 3 User-Friendly Highlights */}
        <div className="border-t border-slate-200/80 pt-16 grid grid-cols-1 md:grid-cols-3 gap-8 text-left">
          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">Foto Asli</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Bebas Kirim Gambar Tanpa Buram</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Abadikan momen dan bagikan dengan kualitas foto penuh, tanpa perlu trik kirim dokumen.
            </p>
          </div>

          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">Tanpa Iklan</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Fokus Sepenuhnya ke Obrolan</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Layar chat yang bersih, rapi, dan menenangkan tanpa pop-up promosi yang salah pencet.
            </p>
          </div>

          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">Pasti Privat</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Otomatis Rahasia Tanpa Ribet</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Pesan kamu hanya bisa dibaca oleh kamu dan penerima. Tidak ada yang bisa mengintip.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
