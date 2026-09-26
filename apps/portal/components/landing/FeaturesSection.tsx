import { 
  ShieldCheck, 
  Video, 
  Lock, 
  Check, 
  X, 
  Sparkles, 
  Zap, 
  EyeOff, 
  Users2, 
  PhoneCall, 
  Wifi,
  ServerOff
} from 'lucide-react';

export function FeaturesSection() {
  return (
    <section id="features" className="py-24 bg-slate-50/60 border-t border-slate-100 relative">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <div className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-700 bg-emerald-100/70 border border-emerald-200/80 px-3.5 py-1 rounded-full uppercase tracking-wider mb-4">
            <Sparkles className="h-3.5 w-3.5 text-emerald-600" />
            <span>Kelebihan Arsitektur</span>
          </div>
          <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
            Bukan Sekadar Aman di Atas Kertas.{' '}
            <span className="text-emerald-600">Aman Secara Arsitektur.</span>
          </h2>
          <p className="mt-4 text-slate-600 text-base sm:text-lg leading-relaxed">
            Sebagian besar messenger populer tetap menyimpan metadata dan kontak Anda di server mereka. LAJU dibangun dari nol dengan filosofi Zero-Knowledge sejati.
          </p>
        </div>

        {/* Story 1: Comparison between Regular Apps vs LAJU */}
        <div className="mb-24 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* Text narrative */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 text-xs font-bold text-emerald-800 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200">
              <ShieldCheck className="h-4 w-4 text-emerald-600" />
              <span>Enkripsi Tanpa Titik Lemah</span>
            </div>
            <h3 className="text-2xl sm:text-3xl font-extrabold text-slate-900 leading-snug">
              Kunci Privat Anda Tidak Pernah Menyentuh Server Kami
            </h3>
            <p className="text-slate-600 text-sm sm:text-base leading-relaxed">
              Di LAJU, pesan teks dan media Anda dikunci dengan <strong>Signal Protocol Double Ratchet</strong>. Setiap pesan baru memiliki kunci kriptografi unik yang langsung dihancurkan setelah terbaca.
            </p>

            <ul className="space-y-3.5 pt-2 text-sm text-slate-700 font-medium">
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Forward Secrecy:</strong> Kunci enkripsi berganti terus-menerus secara otomatis.</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Database SQLCipher Lokal:</strong> Riwayat chat di ponsel terkunci dengan enkripsi perangkat.</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Nol Jejak Metadata:</strong> Kami tidak mencatat siapa yang Anda hubungi dan jam berapa Anda menelepon.</span>
              </li>
            </ul>
          </div>

          {/* Visual Comparison Diagram */}
          <div className="lg:col-span-6">
            <div className="bg-white rounded-3xl border border-slate-200/90 p-6 sm:p-8 shadow-xl soft-shadow space-y-6">
              <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                Perbandingan Arsitektur Transmisi
              </h4>

              {/* The "Other Apps" Flow */}
              <div className="rounded-2xl border border-rose-100 bg-rose-50/50 p-4 sm:p-5">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-bold text-rose-700 flex items-center gap-1.5">
                    <X className="h-4 w-4" /> Messenger Konvensional
                  </span>
                  <span className="text-[11px] font-medium text-rose-600 bg-white px-2 py-0.5 rounded-full border border-rose-200">
                    Beresiko Disadap
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs text-slate-600 gap-2 font-mono">
                  <span className="p-2 bg-white rounded-lg border border-rose-200 font-semibold text-slate-800">Ponsel Anda</span>
                  <span className="text-rose-400">──&gt;</span>
                  <span className="p-2 bg-rose-100 rounded-lg border border-rose-300 font-bold text-rose-800 text-center">
                    Server Membaca & Simpan Log
                  </span>
                  <span className="text-rose-400">──&gt;</span>
                  <span className="p-2 bg-white rounded-lg border border-rose-200 font-semibold text-slate-800">Penerima</span>
                </div>
              </div>

              {/* The "LAJU" Flow */}
              <div className="rounded-2xl border border-emerald-200 bg-emerald-50/60 p-4 sm:p-5">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-bold text-emerald-800 flex items-center gap-1.5">
                    <Check className="h-4 w-4" /> LAJU Secure Messenger
                  </span>
                  <span className="text-[11px] font-bold text-emerald-700 bg-white px-2.5 py-0.5 rounded-full border border-emerald-200">
                    Zero-Knowledge
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs text-slate-700 gap-2 font-mono">
                  <span className="p-2 bg-white rounded-lg border border-emerald-300 font-bold text-slate-900 shadow-sm">Ponsel Anda</span>
                  <span className="text-emerald-600 font-bold">═══════&gt;</span>
                  <span className="p-2 bg-emerald-600 text-white rounded-lg font-bold text-center shadow-sm">
                    Terowongan E2EE Langsung
                  </span>
                  <span className="text-emerald-600 font-bold">═══════&gt;</span>
                  <span className="p-2 bg-white rounded-lg border border-emerald-300 font-bold text-slate-900 shadow-sm">Penerima</span>
                </div>
                <p className="text-[11px] text-emerald-800 mt-3 font-sans">
                  Server hanya meneruskan paket biner teracak tanpa kemampuan melihat isi percakapan.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Story 2: P2P Audio & Video Calling */}
        <div className="mb-24 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* Visual Call Mockup on Left */}
          <div className="lg:col-span-6 order-2 lg:order-1">
            <div className="rounded-3xl border border-slate-200/90 bg-white p-6 sm:p-8 shadow-xl soft-shadow text-left">
              <div className="flex items-center justify-between border-b border-slate-100 pb-4 mb-5">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-2xl bg-emerald-600 text-white flex items-center justify-center font-bold">
                    <Video className="h-5 w-5" />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-900">WebRTC Direct Stream</h4>
                    <p className="text-xs text-emerald-600 font-medium">Koneksi P2P Terverifikasi</p>
                  </div>
                </div>
                <div className="flex items-center gap-1.5 bg-emerald-50 text-emerald-800 border border-emerald-200 px-3 py-1 rounded-full text-xs font-mono font-bold">
                  <Wifi className="h-3.5 w-3.5" />
                  <span>Bitrate 1080p HD</span>
                </div>
              </div>

              <div className="space-y-3">
                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/60 flex items-center justify-between text-xs">
                  <span className="text-slate-600">Latency Panggilan:</span>
                  <span className="font-mono font-bold text-emerald-600 bg-white px-2 py-1 rounded-md border border-slate-200">
                    ~18 ms (Realtime P2P)
                  </span>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/60 flex items-center justify-between text-xs">
                  <span className="text-slate-600">Audio Codec:</span>
                  <span className="font-mono font-bold text-slate-800 bg-white px-2 py-1 rounded-md border border-slate-200">
                    Opus Fullband (48 kHz)
                  </span>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200/60 flex items-center justify-between text-xs">
                  <span className="text-slate-600">Enkripsi Media:</span>
                  <span className="font-mono font-bold text-emerald-700 bg-white px-2 py-1 rounded-md border border-slate-200">
                    SRTP / DTLS 256-Bit
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Text narrative on Right */}
          <div className="lg:col-span-6 order-1 lg:order-2 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 text-xs font-bold text-emerald-800 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200">
              <PhoneCall className="h-4 w-4 text-emerald-600" />
              <span>Panggilan Tanpa Perantara</span>
            </div>
            <h3 className="text-2xl sm:text-3xl font-extrabold text-slate-900 leading-snug">
              Panggilan Suara & Video Langsung Antar-Perangkat
            </h3>
            <p className="text-slate-600 text-sm sm:text-base leading-relaxed">
              Tidak seperti platform lain yang menyalurkan seluruh aliran suara dan video melalui server mereka, LAJU menghubungkan ponsel Anda langsung ke ponsel rekan bicara via protokol <strong>WebRTC Peer-to-Peer</strong>.
            </p>

            <ul className="space-y-3.5 pt-2 text-sm text-slate-700 font-medium">
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Suara Jernih Tanpa Delay:</strong> Latensi minimal karena rute data langsung tanpa memutar ke server.</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Hemat Kuota & Baterai:</strong> Kompresi adaptif menyesuaikan kualitas jaringan ponsel secara otomatis.</span>
              </li>
              <li className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <Check className="h-3.5 w-3.5 stroke-[3]" />
                </div>
                <span><strong>Bebas Sadap Audio:</strong> Aliran stream dienkripsi penuh dengan standar SRTP militer.</span>
              </li>
            </ul>
          </div>
        </div>

        {/* 3 Metric Capability Callouts (Clean horizontal row, not cards) */}
        <div className="border-t border-slate-200/80 pt-16 grid grid-cols-1 md:grid-cols-3 gap-8 text-left">
          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">&lt; 50 ms</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Kecepatan Kilat Transmisi</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Pesan dan media terkirim seketika dengan arsitektur websocket ultra-ringan dan responsif.
            </p>
          </div>

          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">0 Tracker</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Nol Profiling & Iklan</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Tidak ada SDK analitik pihak ketiga. Data pribadi Anda bukan komoditas untuk dijual.
            </p>
          </div>

          <div className="border-l-2 border-emerald-500 pl-5">
            <div className="text-3xl font-black text-slate-900">24/7 Siaga</div>
            <h4 className="text-sm font-bold text-slate-800 mt-1">Push Notifikasi Cerdas</h4>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Panggilan dan pesan masuk selalu berdering tepat waktu, bahkan saat aplikasi tertutup dari recent apps.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
