import type { Metadata } from 'next';
import { ShieldCheck, Lock, EyeOff, Server } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Kebijakan Privasi | LAJU Secure Messenger',
  description: 'Kebijakan privasi resmi LAJU Messenger. Privasi dan enkripsi data Anda adalah prioritas mutlak kami.',
};

export default function PrivacyPage() {
  return (
    <div className="py-20">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-brand-500/30 bg-brand-500/10 px-3.5 py-1 text-xs font-semibold text-brand-400 mb-4">
            <ShieldCheck className="h-4 w-4" />
            <span>Kedaulatan Privasi Pengguna</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black text-white">Kebijakan Privasi LAJU</h1>
          <p className="mt-2 text-xs text-slate-400">Terakhir diperbarui: 26 September 2026</p>
        </div>

        <div className="prose prose-invert max-w-none text-sm text-slate-300 space-y-8 leading-relaxed">
          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2 flex items-center gap-2">
              <Lock className="h-5 w-5 text-brand-400" />
              1. Prinsip Zero-Knowledge & Enkripsi End-to-End
            </h2>
            <p>
              LAJU dibangun di atas fondasi kriptografi kuat. Setiap pesan teks, panggilan suara, panggilan video, foto, audio, dan dokumen yang Anda kirimkan dienkripsi secara end-to-end langsung di perangkat pengirim dan hanya dapat dibuka oleh perangkat penerima. Kami maupun pihak ketiga tidak memiliki kunci privat untuk mendekripsi konten percakapan Anda.
            </p>
          </section>

          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2 flex items-center gap-2">
              <EyeOff className="h-5 w-5 text-brand-400" />
              2. Data yang Kami Simpan dan Tidak Kami Simpan
            </h2>
            <ul className="list-disc list-inside space-y-2 mt-2">
              <li>
                <strong>Isi Pesan & Media:</strong> Tidak pernah disimpan dalam bentuk plaintext di server kami. Pesan transit yang sudah terkirim akan langsung dihapus dari antrean server.
              </li>
              <li>
                <strong>Panggilan Suara & Video:</strong> Dialirkan langsung melalui koneksi Peer-to-Peer (WebRTC P2P). Tidak ada rekaman audio atau video yang disimpan di server.
              </li>
              <li>
                <strong>Pelacak Pihak Ketiga:</strong> Kami tidak menyertakan SDK analitik pelacak iklan pihak ketiga (seperti Google AdMob, Meta Audience Network, atau sejenisnya).
              </li>
            </ul>
          </section>

          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2 flex items-center gap-2">
              <Server className="h-5 w-5 text-brand-400" />
              3. Hak Pengguna
            </h2>
            <p>
              Anda memiliki hak mutlak untuk menghapus akun Anda dan semua data sesi terkait kapan saja melalui menu Pengaturan Akun di dalam aplikasi LAJU. Begitu akun dihapus, seluruh kunci publik dan metadata sesi Anda akan dimusnahkan secara permanen dari basis data.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
