import Link from 'next/link';
import { ShieldCheck, Heart } from 'lucide-react';

export function Footer() {
  return (
    <footer className="border-t border-white/5 bg-slate-950 py-12 text-slate-400 text-xs">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand-500 text-slate-950 font-black text-xs">
              L
            </div>
            <span className="font-bold text-white text-sm">LAJU Secure Messenger</span>
          </div>

          <div className="flex flex-wrap items-center gap-6">
            <Link href="/privacy" className="hover:text-white transition-colors">
              Kebijakan Privasi
            </Link>
            <Link href="/terms" className="hover:text-white transition-colors">
              Ketentuan Layanan
            </Link>
            <Link href="/download" className="hover:text-white transition-colors">
              Unduh Aplikasi
            </Link>
            <a
              href="https://github.com/lajuapp/laju"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-white transition-colors"
            >
              GitHub Source
            </a>
          </div>

          <div className="text-center md:text-right text-[11px] text-slate-400">
            &copy; {new Date().getFullYear()} LAJU. Hak Cipta Dilindungi Undang-Undang.
          </div>
        </div>
      </div>
    </footer>
  );
}
