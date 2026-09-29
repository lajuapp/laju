import type { Metadata } from 'next';
import { 
  FileText, 
  ArrowLeft, 
  CheckCircle2, 
  Scale, 
  Key, 
  Lock, 
  ShieldCheck, 
  AlertTriangle, 
  Trash2, 
  HelpCircle, 
  Download,
  Server
} from 'lucide-react';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Ketentuan Layanan | LAJU Secure Messenger',
  description: 'Ketentuan layanan resmi LAJU Messenger. Komunikasi aman, adil, transparan, dan bebas identitas pribadi.',
};

export default function TermsPage() {
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

        {/* Hero Section of Terms Page */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Manifesto Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-4 py-1.5 text-xs font-bold text-stone-700 shadow-sm">
              <Scale className="h-4 w-4 text-[#0D382C]" />
              <span>Perjanjian & Kedaulatan Pengguna</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              Layanan Adil, Transparan,<br />
              & Bebas Identitas Pribadi.
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              LAJU menyediakan infrastruktur pesan dan panggilan terenkripsi end-to-end tanpa memerlukan nomor telepon atau email. Ketentuan ini disusun secara lugas dan adil untuk menjamin kebebasan berkomunikasi sekaligus melindungi ekosistem dari eksploitasi dan kejahatan.
            </p>

            {/* Core Terms Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Tanpa Email & Nomor Telepon</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Kepemilikan Mutlak Isi Percakapan</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Bebas Penguncian Vendor (No Lock-In)</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>Penghapusan Akun Seketika</span>
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
                href="#rincian-ketentuan"
                className="flex items-center gap-2 rounded-full border border-stone-300 bg-white/80 px-5 py-3 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-white hover:text-slate-900 transition-all"
              >
                <span>Baca Rincian Ketentuan ↓</span>
              </a>
            </div>
          </div>

          {/* Right: Visual Illustration Card */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white p-8 space-y-6">
              <div className="h-14 w-14 rounded-2xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-[#0D382C]">
                <ShieldCheck className="h-7 w-7" />
              </div>
              <div>
                <h3 className="text-xl font-extrabold text-slate-900">Komitmen Layanan LAJU</h3>
                <p className="mt-2 text-xs text-slate-600 leading-relaxed">
                  Kami tidak memonetisasi pengguna, tidak memasang algoritma kurasi konten manipulatif, dan tidak bekerja sama dengan broker data. Anda memegang kendali penuh atas identitas kriptografi Anda.
                </p>
              </div>
              <div className="space-y-3 pt-2 border-t border-stone-100 text-xs text-slate-700 font-medium">
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>Enkripsi End-to-End</span>
                  <span className="font-bold text-emerald-700">Aktif Penuh</span>
                </div>
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>Persyaratan No. Telepon / Email</span>
                  <span className="font-bold text-emerald-700">Tidak Ada (0%)</span>
                </div>
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>Penyimpanan Arsip Pesan di Cloud</span>
                  <span className="font-bold text-rose-600">Dilarang / Nol</span>
                </div>
              </div>
            </div>
          </div>

        </div>

        {/* 4 Core Pillars Grid */}
        <div className="mb-20">
          <div className="text-center max-w-2xl mx-auto mb-10">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              4 Landasan Ketentuan Layanan LAJU
            </h2>
            <p className="mt-2 text-xs sm:text-sm text-slate-600">
              Prinsip keadilan dan transparansi yang mengikat pengembang dan seluruh pengguna.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 text-left">
            {/* Pillar 1 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Key className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Tanpa Identitas Pribadi</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Anda tidak perlu memberikan nomor telepon, email, atau identitas kependudukan. Akun Anda adalah kunci kriptografi Anda.
              </p>
            </div>

            {/* Pillar 2 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Lock className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Kedaulatan Konten</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Anda adalah pemilik tunggal dari setiap percakapan dan media yang Anda kirimkan. Kami tidak mengklaim hak cipta apa pun.
              </p>
            </div>

            {/* Pillar 3 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <AlertTriangle className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Anti-Spam & Eksploitasi</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Platform dilarang keras digunakan untuk penipuan finansial, peretasan, malware, bot spam massal, atau kejahatan fisik.
              </p>
            </div>

            {/* Pillar 4 */}
            <div className="p-6 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-3">
              <div className="h-10 w-10 rounded-2xl bg-stone-100 flex items-center justify-center text-[#0D382C]">
                <Trash2 className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">Hak Hapus Instan</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Anda memiliki hak tanpa syarat untuk menghapus akun kapan saja. Seluruh kunci publik dan sesi dimusnahkan seketika.
              </p>
            </div>
          </div>
        </div>

        {/* Detailed Legal & Terms Articles */}
        <div id="rincian-ketentuan" className="max-w-4xl mx-auto space-y-8 text-sm text-slate-600 leading-relaxed text-left">
          
          <div className="border-b border-stone-200 pb-4 mb-8">
            <h2 className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Rincian Syarat & Ketentuan Penggunaan Layanan
            </h2>
            <p className="mt-1 text-xs text-slate-500">
              Terakhir diperbarui: September 2026 • Mengikat secara sah bagi seluruh pengguna platform LAJU
            </p>
          </div>

          {/* Section 1 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <FileText className="h-5 w-5 text-[#0D382C]" />
              <span>1. Penerimaan & Ruang Lingkup Layanan</span>
            </h3>
            <p>
              Dengan mengunduh, menginstal, atau mengakses aplikasi LAJU, Anda menyatakan telah membaca, memahami, dan menyetujui Ketentuan Layanan ini serta Kebijakan Privasi kami. LAJU menyediakan infrastruktur komunikasi instan terenkripsi berkecepatan tinggi yang menjamin kerahasiaan penuh antara para penggunanya.
            </p>
            <p>
              Jika Anda tidak menyetujui salah satu klausul dalam ketentuan ini, Anda dipersilakan untuk tidak menggunakan aplikasi atau segera menghapus instalasi aplikasi dari perangkat Anda.
            </p>
          </section>

          {/* Section 2 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Key className="h-5 w-5 text-[#0D382C]" />
              <span>2. Ketiadaan Persyaratan Identitas Pribadi (No PII Required)</span>
            </h3>
            <p>
              LAJU dirancang agar Anda dapat berkomunikasi secara mandiri tanpa harus menyerahkan kedaulatan data pribadi Anda:
            </p>
            <ul className="list-disc list-inside space-y-2 pl-2">
              <li>
                <strong>Tidak Memerlukan Nomor Telepon:</strong> Pendaftaran tidak menggunakan nomor kartu SIM atau verifikasi SMS OTP.
              </li>
              <li>
                <strong>Tidak Memerlukan Alamat Email:</strong> Anda tidak diwajibkan mendaftarkan, menautkan, atau mengonfirmasi alamat surat elektronik.
              </li>
              <li>
                <strong>Tidak Memerlukan Identitas Resmi:</strong> Kami tidak meminta nama resmi KTP/Paspor, foto identitas, ataupun data biometrik.
              </li>
              <li>
                <strong>Identitas Berbasis Kriptografi:</strong> Akun Anda diasosiasikan secara langsung dengan pasangan kunci kriptografi asimetris yang dihasilkan di perangkat Anda sendiri.
              </li>
            </ul>
          </section>

          {/* Section 3 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Lock className="h-5 w-5 text-[#0D382C]" />
              <span>3. Tanggung Jawab atas Kunci Kriptografi & PIN Keamanan</span>
            </h3>
            <p>
              Karena LAJU menerapkan arsitektur <em>Zero-Knowledge</em>, server kami <strong>tidak pernah menyimpan salinan kunci privat maupun PIN keamanan Anda</strong>. Konsekuensinya:
            </p>
            <ul className="list-disc list-inside space-y-2 pl-2">
              <li>
                Anda memegang tanggung jawab penuh untuk mengingat PIN keamanan dan mencadangkan data akun Anda.
              </li>
              <li>
                Pihak pengembang LAJU tidak memiliki pintu belakang (backdoor) teknis untuk memulihkan pesan jika Anda kehilangan seluruh kunci akses dan perangkat Anda.
              </li>
            </ul>
          </section>

          {/* Section 4 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-[#0D382C]" />
              <span>4. Pedoman Penggunaan yang Bertanggung Jawab & Larangan</span>
            </h3>
            <p>
              Untuk menjaga integritas dan kelangsungan jaringan LAJU bagi seluruh pengguna, Anda setuju untuk TIDAK menggunakan layanan ini untuk:
            </p>
            <ul className="list-disc list-inside space-y-2 pl-2">
              <li>
                Penyebaran pesan massal yang tidak diminta (Spam) atau penggunaan bot automasi liar yang membebani node perutean relay.
              </li>
              <li>
                Penyebaran perangkat lunak perusak (malware, spyware, ransomware, trojan) atau tautan eksploitasi keamanan siber.
              </li>
              <li>
                Penipuan finansial, pemerasan, atau eksploitasi ilegal terhadap hak asasi individu.
              </li>
              <li>
                Upaya merekayasa balik (reverse-engineering) server relay dengan tujuan merusak atau melumpuhkan ketersediaan jaringan.
              </li>
            </ul>
            <p className="text-xs text-amber-700 bg-amber-50 p-3 rounded-xl border border-amber-200 mt-2">
              Pelanggaran berat terhadap pedoman ini akan mengakibatkan pembatasan Trust Score akun dan penolakan koneksi relay oleh jaringan tanpa pemberitahuan sebelumnya.
            </p>
          </section>

          {/* Section 5 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Server className="h-5 w-5 text-[#0D382C]" />
              <span>5. Ketersediaan Layanan & Penafian Jaminan</span>
            </h3>
            <p>
              Layanan relay LAJU disediakan dengan komitmen stabilitas tinggi (target ketersediaan SLA 99.99%). Namun demikian, layanan disediakan atas dasar <em>"sebagaimana adanya" (as is)</em>.
            </p>
            <p>
              Kami tidak bertanggung jawab atas keterlambatan atau kegagalan transmisi pesan yang disebabkan oleh pemadaman jaringan telekomunikasi global, gangguan transit ISP pengguna, atau kebijakan pembatasan jaringan di tingkat penyedia internet lokal pengguna.
            </p>
          </section>

          {/* Section 6 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <Trash2 className="h-5 w-5 text-[#0D382C]" />
              <span>6. Hak Pengakhiran & Penghapusan Akun Seketika</span>
            </h3>
            <p>
              Anda berhak menghentikan penggunaan layanan kapan pun tanpa dikenakan biaya atau syarat administrasi. Cukup gunakan menu <strong>Pengaturan &gt; Akun &gt; Hapus Akun</strong> di aplikasi. Seluruh kunci publik akun Anda akan segera dianonimkan dan dihapus dari direktori server.
            </p>
          </section>

          {/* Section 7 */}
          <section className="p-6 sm:p-8 rounded-3xl bg-white border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <HelpCircle className="h-5 w-5 text-[#0D382C]" />
              <span>7. Pertanyaan & Bantuan Resmi</span>
            </h3>
            <p>
              Jika Anda memerlukan klarifikasi mengenai ketentuan ini atau memiliki pertanyaan teknis, silakan hubungi tim kami:
            </p>
            <div className="p-3.5 rounded-2xl bg-stone-50 border border-stone-200 text-xs font-mono text-slate-800 inline-block font-semibold">
              support@laju.chat
            </div>
          </section>

        </div>

      </div>
    </div>
  );
}
