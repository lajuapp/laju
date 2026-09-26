import type { Metadata } from 'next';
import { FileText, ArrowLeft } from 'lucide-react';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Ketentuan Layanan | LAJU Secure Messenger',
  description: 'Ketentuan layanan penggunaan platform LAJU Secure Messenger.',
};

export default function TermsPage() {
  return (
    <div className="py-16 sm:py-24 bg-white">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>Kembali ke Beranda</span>
        </Link>

        <div className="mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-3.5 py-1 text-xs font-bold text-emerald-800 mb-4">
            <FileText className="h-4 w-4 text-emerald-600" />
            <span>Ketentuan Penggunaan</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold text-slate-900 tracking-tight">Ketentuan Layanan LAJU</h1>
          <p className="mt-2 text-xs text-slate-500">Terakhir diperbarui: 26 September 2026</p>
        </div>

        <div className="space-y-8 text-sm text-slate-600 leading-relaxed">
          <section className="p-6 sm:p-8 rounded-3xl bg-slate-50/70 border border-slate-200/80">
            <h2 className="text-lg font-bold text-slate-900 mb-2">1. Penerimaan Ketentuan</h2>
            <p>
              Dengan mengunduh, memasang, atau menggunakan aplikasi LAJU, Anda menyetujui untuk terikat oleh Ketentuan Layanan ini. Jika Anda tidak menyetujui salah satu poin ketentuan, mohon untuk tidak menggunakan layanan kami.
            </p>
          </section>

          <section className="p-6 sm:p-8 rounded-3xl bg-slate-50/70 border border-slate-200/80">
            <h2 className="text-lg font-bold text-slate-900 mb-2">2. Penggunaan yang Bertanggung Jawab</h2>
            <p>
              Anda setuju untuk tidak menggunakan layanan LAJU untuk tindakan yang melanggar hukum, penipuan, penyebaran malware, pelecehan, atau ancaman terhadap integritas fisik pihak lain.
            </p>
          </section>

          <section className="p-6 sm:p-8 rounded-3xl bg-slate-50/70 border border-slate-200/80">
            <h2 className="text-lg font-bold text-slate-900 mb-2">3. Penafian Tanggung Jawab</h2>
            <p>
              Layanan LAJU disediakan "sebagaimana adanya" (*as is*). Meskipun kami menerapkan standar keamanan kriptografi terbaik, kami tidak memberikan jaminan tanpa cela atas ketersediaan layanan selama terjadi bencana alam atau gangguan jaringan global.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
