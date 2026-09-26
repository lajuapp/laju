import type { Metadata } from 'next';
import { 
  ShieldCheck, 
  Lock, 
  EyeOff, 
  Server, 
  ArrowLeft, 
  CheckCircle2, 
  Key, 
  FileText, 
  Smartphone, 
  Trash2, 
  Download,
  HelpCircle
} from 'lucide-react';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Kebijakan Privasi | LAJU Secure Messenger',
  description: 'Kebijakan privasi resmi LAJU Messenger. Privasi dan enkripsi data Anda adalah prioritas mutlak kami.',
};

export default function PrivacyPage() {
  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>Kembali ke Beranda</span>
        </Link>

        {/* Hero Section of Privacy Page */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Manifesto Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-4 py-1.5 text-xs font-bold text-stone-700 shadow-sm">
              <ShieldCheck className="h-4 w-4 text-[#0D382C]" />
              <span>Kedaulatan Privasi Pengguna</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              Privasimu Bukan Komoditas,<br />
              Tapi Hak Mutlak.
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              Kami merancang LAJU dari fondasi pertama dengan prinsip <em>zero-knowledge</em>: apa yang Anda bicarakan, siapa yang Anda hubungi, dan apa yang Anda bagikan adalah sepenuhnya milik Anda. Kami tidak memiliki kunci untuk mengintip isi percakapan Anda.
            </p>

            {/* Core Privacy Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Enkripsi End-to-End Bawaan</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>100% Bebas Iklan & Pelacak</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Kunci Privat Hanya di Perangkat</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Panggilan P2P Terenkripsi Langsung</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3 text-xs sm:text-sm font-semibold text-white shadow hover:bg-[#134E3E] transition-all"
              >
                <Download className="h-4 w-4" />
                <span>Unduh Aplikasi Aman</span>
              </Link>
              <a
                href="#rincian-kebijakan"
                className="flex items-center gap-2 rounded-full border border-stone-300 bg-white/80 px-5 py-3 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-white hover:text-slate-900 transition-all"
              >
                <span>Baca Rincian Kebijakan ↓</span>
              </a>
            </div>
          </div>

          {/* Right: Gorgeous Luminous Shield & Phone Artwork */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white group">
              <img
                src="/images/privacy-hero.jpg"
                alt="LAJU Keamanan dan Perlindungan Privasi"
                className="w-full h-auto object-cover transform group-hover:scale-[1.02] transition-transform duration-500 ease-out"
              />
              <div className="absolute bottom-4 inset-x-4 p-3.5 rounded-2xl bg-black/40 backdrop-blur-md border border-white/10 text-white text-xs flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Lock className="h-3.5 w-3.5 text-emerald-400" />
                  <span className="font-semibold text-[11px]">Enkripsi Aktif di Seluruh Pesan</span>
                </div>
                <span className="text-[10px] font-mono text-emerald-300 font-bold">256-BIT</span>
              </div>
            </div>
          </div>

        </div>

        {/* 4 Architectural Pillars Grid */}
        <div className="mb-20">
          <div className="text-center max-w-2xl mx-auto mb-10">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              4 Pilar Keamanan Data di LAJU
            </h2>
            <p className="mt-2 text-xs sm:text-sm text-slate-600">
              Bagaimana kami memastikan percakapan Anda tetap menjadi milik Anda seorang.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 text-left">
            {/* Pillar 1 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Lock className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Enkripsi End-to-End</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Setiap pesan teks, gambar, video, dan dokumen dienkripsi langsung di ponsel pengirim dan hanya dapat didekripsi oleh ponsel penerima.
              </p>
            </div>

            {/* Pillar 2 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Key className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Zero-Knowledge</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Kunci privat Anda tersimpan aman secara lokal di perangkat Anda. Server kami tidak memiliki kunci untuk membaca isi pesan Anda.
              </p>
            </div>

            {/* Pillar 3 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <EyeOff className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Tanpa Pelacak Iklan</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Bebas 100% dari SDK analitik pelacak pihak ketiga (seperti AdMob atau Meta). Kami tidak menjual profil Anda kepada siapa pun.
              </p>
            </div>

            {/* Pillar 4 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Trash2 className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Penghapusan Bersih</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Pesan yang sudah diterima langsung dibersihkan dari server. Fitur pesan sementara memungkinkan riwayat terhapus otomatis di kedua sisi.
              </p>
            </div>
          </div>
        </div>

        {/* Detailed Legal & Policy Articles */}
        <div id="rincian-kebijakan" className="max-w-4xl mx-auto space-y-8 text-sm text-slate-600 leading-relaxed text-left">
          
          <div className="border-b border-stone-200 pb-4 mb-8">
            <h2 className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rincian Ketentuan Kebijakan Privasi
            </h2>
            <p className="mt-1 text-xs text-slate-500">
              Terakhir diperbarui: 26 September 2026 • Berlaku efektif untuk seluruh pengguna platform LAJU
            </p>
          </div>

          {/* Section 1 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Smartphone className="h-5 w-5 text-[#0D382C]" />
              <span>1. Data yang Diperlukan untuk Registrasi</span>
            </h3>
            <p>
              Untuk menggunakan layanan LAJU, Anda hanya perlu mendaftarkan nomor ponsel aktif untuk verifikasi kode satu kali (OTP). Nomor ponsel ini digunakan sebagai pengenal akun unik agar kontak Anda dapat menemukan Anda di dalam sistem LAJU.
            </p>
            <p>
              Kami tidak meminta nama asli lengkap, alamat fisik, nomor identitas kependudukan (KTP/Passport), tanggal lahir, maupun informasi pembayaran apa pun.
            </p>
          </section>

          {/* Section 2 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <EyeOff className="h-5 w-5 text-[#0D382C]" />
              <span>2. Data yang Sama Sekali Tidak Pernah Kami Simpan</span>
            </h3>
            <ul className="list-disc list-inside space-y-2.5">
              <li>
                <strong className="text-slate-900">Isi Percakapan:</strong> Pesan teks, dokumen, rekaman suara, foto, dan video tidak pernah berada dalam bentuk terbuka (plaintext) di infrastruktur server kami.
              </li>
              <li>
                <strong className="text-slate-900">Buku Kontak Mentah:</strong> Pencocokan kontak dilakukan dengan enkripsi searah (hashing aman) di memori sementara, tanpa menyalin nomor atau nama di buku telepon Anda ke basis data server.
              </li>
              <li>
                <strong className="text-slate-900">Lokasi Real-Time:</strong> Kami tidak meminta izin pelacakan lokasi latar belakang (GPS tracking) dan tidak merekam koordinat geografis Anda.
              </li>
              <li>
                <strong className="text-slate-900">Rekaman Panggilan:</strong> Panggilan suara dan video dialirkan langsung antar-perangkat menggunakan protokol WebRTC Peer-to-Peer terenkripsi. Server hanya memfasilitasi pertukaran sinyal awal (signaling handshake).
              </li>
            </ul>
          </section>

          {/* Section 3 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Server className="h-5 w-5 text-[#0D382C]" />
              <span>3. Transit Pesan & Antrean Pengiriman</span>
            </h3>
            <p>
              Jika kontak penerima sedang tidak terhubung ke jaringan internet saat pesan dikirimkan, pesan terenkripsi akan disimpan sementara di antrean relay server. Begitu penerima terhubung dan pesan berhasil terkirim, berkas transit terenkripsi tersebut akan segera dihapus permanen dari memori antrean server kami.
            </p>
          </section>

          {/* Section 4 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Trash2 className="h-5 w-5 text-[#0D382C]" />
              <span>4. Hak Penghapusan Akun & Data Pengguna</span>
            </h3>
            <p>
              Kedaulatan privasi ada di tangan Anda. Kapan pun Anda memutuskan untuk berhenti menggunakan LAJU, Anda dapat menggunakan opsi <strong>Hapus Akun</strong> di menu Pengaturan aplikasi.
            </p>
            <p>
              Tindakan ini akan secara permanen dan seketika menghapus profil publik Anda, metadata sesi, kunci publik terkait, dan keanggotaan grup dari basis data kami tanpa opsi pemulihan.
            </p>
          </section>

          {/* Section 5 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <HelpCircle className="h-5 w-5 text-[#0D382C]" />
              <span>5. Hubungi Tim Privasi LAJU</span>
            </h3>
            <p>
              Jika Anda memiliki pertanyaan teknis, audit keamanan, atau masukan terkait perlindungan privasi di platform LAJU, silakan hubungi tim kami melalui email resmi:
            </p>
            <div className="p-3.5 rounded-2xl bg-stone-50 border border-stone-200 text-xs font-mono text-slate-800 inline-block font-semibold">
              privacy@laju.chat
            </div>
          </section>

        </div>

      </div>
    </div>
  );
}
