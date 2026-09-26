import { Lock, Key, Server, Cpu, CheckCircle } from 'lucide-react';

export function SecuritySection() {
  return (
    <section id="security" className="py-24 relative overflow-hidden border-t border-white/5">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-teal-500/30 bg-teal-500/10 px-3.5 py-1 text-xs font-semibold text-teal-400 mb-6">
              <Lock className="h-3.5 w-3.5" />
              <span>Arsitektur Kriptografi Mandiri</span>
            </div>
            <h2 className="text-3xl sm:text-4xl font-black text-white tracking-tight">
              Kunci Privat Anda Tidak Pernah Keluar dari Ponsel Anda
            </h2>
            <p className="mt-4 text-slate-300 text-sm sm:text-base leading-relaxed">
              Di LAJU, prinsip utama kami adalah <strong>Zero-Knowledge</strong>. Server perantara hanya bertindak sebagai pemancar paket terenkripsi biner tanpa kemampuan membaca teks, foto, ataupun rekaman suara obrolan Anda.
            </p>

            <div className="mt-8 space-y-4">
              <div className="flex items-start gap-3.5">
                <div className="p-1 rounded-full bg-brand-500/10 text-brand-400 mt-1">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-white">Signal Protocol Double Ratchet</h4>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Kunci enkripsi berganti secara matematis di setiap pesan, sehingga pesan masa lalu dan masa depan tetap aman meski satu kunci terkompromi (Forward Secrecy).
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3.5">
                <div className="p-1 rounded-full bg-brand-500/10 text-brand-400 mt-1">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-white">Keamanan Database Lokal Terenkripsi</h4>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Penyimpanan pesan di ponsel diamankan dengan enkripsi SQLCipher berbasis kunci biometrik dan sandi perangkat Anda.
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3.5">
                <div className="p-1 rounded-full bg-brand-500/10 text-brand-400 mt-1">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-white">Bebas dari Big Tech Monopoli</h4>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Infrastruktur independen berdaulat yang dirancang untuk menjaga kedaulatan data pengguna tanpa ketergantungan sepihak.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div className="relative">
            <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-6 sm:p-8 backdrop-blur-xl shadow-2xl relative">
              <div className="flex items-center justify-between border-b border-white/10 pb-4 mb-6">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-brand-500/20 text-brand-400">
                    <Key className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="text-sm font-bold text-white">Protokol Keamanan Multi-Lapis</div>
                    <div className="text-xs text-slate-400">Verifikasi Enkripsi E2EE Aktif</div>
                  </div>
                </div>
                <span className="text-[11px] font-mono font-bold bg-brand-500/20 text-brand-300 px-2.5 py-1 rounded-full">
                  AES-256-GCM
                </span>
              </div>

              <div className="space-y-4 font-mono text-xs">
                <div className="p-3.5 rounded-xl bg-black/40 border border-white/5 text-slate-300">
                  <span className="text-brand-400 font-bold">CLIENT_A &rarr; INITIATE_SESSION:</span>
                  <div className="text-slate-400 mt-1 truncate">
                    Pubkey: 04a89fb31c7e9014b2d398ef91823...
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-black/40 border border-white/5 text-slate-300">
                  <span className="text-teal-400 font-bold">DOUBLE_RATCHET_STEP:</span>
                  <div className="text-slate-400 mt-1 truncate">
                    HMAC-SHA256 Derivation: Ephemeral ratchet updated.
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-brand-950/40 border border-brand-500/20 text-brand-300">
                  <span className="font-bold">STATUS_DECRYPTION:</span>
                  <div className="mt-1">
                    Hanya penerima sah yang dapat mendengarkan audio atau membaca isi payload.
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
