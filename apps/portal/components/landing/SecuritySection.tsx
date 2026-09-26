import { Lock, Key, CheckCircle, Terminal, ShieldCheck } from 'lucide-react';

export function SecuritySection() {
  return (
    <section id="security" className="py-24 bg-white border-t border-slate-100 relative">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* Left Narrative */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-3.5 py-1 text-xs font-bold text-emerald-800">
              <Lock className="h-3.5 w-3.5 text-emerald-600" />
              <span>Transparansi Kriptografi Terverifikasi</span>
            </div>

            <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
              Kriptografi Berstandar Terbuka. Tanpa Pintu Belakang.
            </h2>

            <p className="text-slate-600 text-sm sm:text-base leading-relaxed">
              Kami tidak menciptakan algoritma baru yang belum teruji. LAJU mengimplementasikan standar kriptografi paling dihormati di industri keamanan siber dunia:
            </p>

            <div className="space-y-4 pt-2">
              <div className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-slate-900">Signal Double Ratchet Algorithm</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Protokol pertukaran kunci ephemeral berbasis KDF ratchet yang memperbarui kunci enkripsi di setiap gelembung percakapan.
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-slate-900">Enkripsi Simetris AES-256-GCM</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Menjamin kerahasiaan sekaligus integritas pesan (Authenticated Encryption), mencegah pesan dimanipulasi di tengah jalan.
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className="p-1 rounded-full bg-emerald-100 text-emerald-700 mt-0.5">
                  <CheckCircle className="h-4 w-4" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-slate-900">Kurva Eliptik X25519 / Ed25519</h4>
                  <p className="text-xs text-slate-600 mt-0.5">
                    Pertukaran kunci publik dan tanda tangan digital dengan performa tinggi dan resistensi terhadap serangan kanal samping (side-channel).
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Right: Clean White Protocol Inspector */}
          <div className="lg:col-span-6">
            <div className="rounded-3xl border border-slate-200/90 bg-slate-900 text-slate-100 p-6 sm:p-8 shadow-2xl relative text-left">
              {/* Terminal Window Header */}
              <div className="flex items-center justify-between border-b border-slate-800 pb-4 mb-5">
                <div className="flex items-center gap-2">
                  <div className="h-3 w-3 rounded-full bg-rose-500/80" />
                  <div className="h-3 w-3 rounded-full bg-amber-500/80" />
                  <div className="h-3 w-3 rounded-full bg-emerald-500/80" />
                </div>
                <div className="flex items-center gap-1.5 text-xs font-mono text-slate-400">
                  <Terminal className="h-3.5 w-3.5" />
                  <span>handshake_verifier.ts</span>
                </div>
                <span className="text-[10px] font-mono font-bold bg-emerald-500/20 text-emerald-400 px-2 py-0.5 rounded-full">
                  VERIFIED
                </span>
              </div>

              {/* Code / Protocol Output */}
              <div className="space-y-3 font-mono text-xs leading-relaxed overflow-x-auto">
                <p className="text-slate-500">// Langkah 1: Pembangkitan Kunci Sesi di Ponsel Klien</p>
                <p className="text-emerald-400">
                  const session = await DoubleRatchet.initiate({'{'}
                </p>
                <p className="pl-4 text-slate-300">
                  peerIdentityKey: <span className="text-amber-300">"04a89fb31c7e9014b2..."</span>,
                </p>
                <p className="pl-4 text-slate-300">
                  ephemeralKey: <span className="text-amber-300">Curve25519.generateKeyPair()</span>
                </p>
                <p className="text-emerald-400">{'}'});</p>

                <p className="text-slate-500 pt-2">// Langkah 2: Enkripsi Payload Tanpa Sentuhan Server</p>
                <p className="text-teal-300">
                  const ciphertext = await session.encrypt(rawMessage);
                </p>
                <div className="p-3 rounded-xl bg-slate-950/80 border border-slate-800 text-[11px] text-slate-400">
                  <div className="text-emerald-400 font-semibold mb-1">✓ Status Transmisi:</div>
                  Server hanya melihat hash acak terenkripsi: <span className="text-slate-300">d7a1f5...9b82e4</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
