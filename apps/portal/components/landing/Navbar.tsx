import Link from 'next/link';
import { ShieldCheck, Download, ExternalLink, ArrowRight } from 'lucide-react';

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-white/5 bg-[#090d16]/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center gap-2.5 group">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-500 text-slate-950 font-black shadow-lg shadow-brand-500/25 transition-transform group-hover:scale-105">
            L
          </div>
          <div className="flex flex-col">
            <span className="text-lg font-black tracking-wider text-white">LAJU</span>
            <span className="text-[10px] font-semibold text-brand-400 tracking-widest uppercase -mt-1">
              Secure Messenger
            </span>
          </div>
        </Link>

        {/* Navigation Links */}
        <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-slate-300">
          <Link href="/#features" className="hover:text-white transition-colors">
            Fitur
          </Link>
          <Link href="/#security" className="hover:text-white transition-colors">
            Keamanan
          </Link>
          <Link href="/download" className="hover:text-white transition-colors">
            Download
          </Link>
          <Link href="/privacy" className="hover:text-white transition-colors">
            Privasi
          </Link>
        </nav>

        {/* CTA Buttons */}
        <div className="flex items-center gap-3">
          <Link
            href="/download"
            className="flex items-center gap-2 rounded-xl bg-brand-500 px-4 py-2 text-xs font-bold text-slate-950 shadow-md shadow-brand-500/20 hover:bg-brand-400 transition-all active:scale-95"
          >
            <Download className="h-4 w-4" />
            <span className="hidden sm:inline">Unduh</span> APK
          </Link>
        </div>
      </div>
    </header>
  );
}
