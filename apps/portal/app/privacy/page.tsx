import type { Metadata } from 'next';
import { ShieldCheck, Lock, EyeOff, Server, ArrowLeft } from 'lucide-react';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Kebijakan Privasi | LAJU Secure Messenger',
  description: 'Kebijakan privasi resmi LAJU Messenger. Privasi dan enkripsi data Anda adalah prioritas mutlak kami.',
};

export default function PrivacyPage() {
  return (
    <div className="py-16 sm:py-24 bg-[#F5F4EF]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>Kembali ke Beranda</span>
        </Link>

        <div className="mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-3.5 py-1 text-xs font-bold text-stone-700 mb-4 shadow-sm">
            <ShieldCheck className="h-4 w-4 text-[#0D382C]" />
            <span>Kedaulatan Privasi Pengguna</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-slate-900 tracking-tight">Kebijakan Privasi LAJU</h1>
          <p className="mt-2 text-xs text-slate-500">Terakhir diperbarui: 26 September 2026</p>
        </div>

        <div className="space-y-8 text-sm text-slate-600 leading-relaxed">
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm">
            <h2 className="text-lg font-bold text-slate-900 mb-3 flex items-center gap-2">
              <Lock className="h-5 w-5 text-[#0D382C]" />
              1. Prinsip Zero-Knowledge & Enkripsi End-to-End
            </h2>
            <p>
              LAJU dibangun di atas fondasi kriptografi kuat. Setiap pesan teks, panggilan suara, panggilan video, foto, audio, dan dokumen yang Anda kirimkan dienkripsi secara end-to-end langsung di perangkat pengirim dan hanya dapat dibuka oleh perangkat penerima. Kami maupun pihak ketiga tidak memiliki kunci privat untuk mendekripsi konten percakapan Anda.
            </p>
          </section>

          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm">
            <h2 className="text-lg font-bold text-slate-900 mb-3 flex items-center gap-2">
              <EyeOff className="h-5 w-5 text-[#0D382C]" />
              2. Data yang Kami Simpan dan Tidak Kami Simpan
            </h2>
            <ul className="list-disc list-inside space-y-2 mt-2">
              <li>
                <strong className="text-slate-900">Isi Pesan & Media:</strong> Tidak pernah disimpan dalam bentuk plaintext di server kami. Pesan transit yang sudah terkirim akan langsung dihapus dari antrean server.
              </li>
              <li>
                <strong className="text-slate-900">Panggilan Suara & Video:</strong> Dialirkan langsung melalui koneksi Peer-to-Peer (WebRTC P2P). Tidak ada rekaman audio atau video yang disimpan di server.
              </li>
              <li>
                <strong className="text-slate-900">Pelacak Pihak Ketiga:</strong> Kami tidak menyertakan SDK analitik pelacak iklan pihak ketiga (seperti Google AdMob, Meta Audience Network, atau sejenisnya).
              </li>
            </ul>
          </section>

          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm">
            <h2 className="text-lg font-bold text-slate-900 mb-3 flex items-center gap-2">
              <Server className="h-5 w-5 text-[#0D382C]" />
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
