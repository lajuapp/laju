import type { Metadata } from 'next';
import { FileText, CheckCircle2 } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Ketentuan Layanan | LAJU Secure Messenger',
  description: 'Ketentuan layanan penggunaan platform LAJU Secure Messenger.',
};

export default function TermsPage() {
  return (
    <div className="py-20">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <div className="mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-brand-500/30 bg-brand-500/10 px-3.5 py-1 text-xs font-semibold text-brand-400 mb-4">
            <FileText className="h-4 w-4" />
            <span>Ketentuan Penggunaan</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black text-white">Ketentuan Layanan LAJU</h1>
          <p className="mt-2 text-xs text-slate-400">Terakhir diperbarui: 26 September 2026</p>
        </div>

        <div className="prose prose-invert max-w-none text-sm text-slate-300 space-y-8 leading-relaxed">
          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2">1. Penerimaan Ketentuan</h2>
            <p>
              Dengan mengunduh, memasang, atau menggunakan aplikasi LAJU, Anda menyetujui untuk terikat oleh Ketentuan Layanan ini. Jika Anda tidak menyetujui salah satu poin ketentuan, mohon untuk tidak menggunakan layanan kami.
            </p>
          </section>

          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2">2. Penggunaan yang Bertanggung Jawab</h2>
            <p>
              Anda setuju untuk tidak menggunakan layanan LAJU untuk tindakan yang melanggar hukum, penipuan, penyebaran malware, pelecehan, atau ancaman terhadap integritas fisik pihak lain.
            </p>
          </section>

          <section className="p-6 rounded-2xl bg-white/[0.02] border border-white/5">
            <h2 className="text-lg font-bold text-white mb-2">3. Penafian Tanggung Jawab</h2>
            <p>
              Layanan LAJU disediakan "sebagaimana adanya" (*as is*). Meskipun kami menerapkan standar keamanan kriptografi terbaik, kami tidak memberikan jaminan tanpa cela atas ketersediaan layanan selama terjadi bencana alam atau gangguan jaringan global.
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
