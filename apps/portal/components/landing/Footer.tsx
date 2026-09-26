import Link from 'next/link';
import { ShieldCheck } from 'lucide-react';

export function Footer() {
  return (
    <footer className="border-t border-slate-100 bg-white py-12 text-slate-500 text-xs">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          {/* Logo & Name */}
          <div className="flex items-center gap-3">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-emerald-600 text-white font-black text-xs">
              L
            </div>
            <span className="font-bold text-slate-900 text-sm">LAJU Secure Messenger</span>
          </div>

          {/* Links */}
          <div className="flex flex-wrap items-center gap-6 font-medium">
            <Link href="/privacy" className="hover:text-slate-900 transition-colors">
              Kebijakan Privasi
            </Link>
            <Link href="/terms" className="hover:text-slate-900 transition-colors">
              Ketentuan Layanan
            </Link>
            <Link href="/download" className="hover:text-slate-900 transition-colors">
              Unduh Aplikasi
            </Link>
            <a
              href="https://github.com/lajuapp/laju"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-slate-900 transition-colors"
            >
              GitHub Source
            </a>
          </div>

          {/* Copyright */}
          <div className="text-center md:text-right text-[11px] text-slate-400">
            &copy; {new Date().getFullYear()} LAJU. Hak Cipta Dilindungi Undang-Undang.
          </div>
        </div>
      </div>
    </footer>
  );
}
