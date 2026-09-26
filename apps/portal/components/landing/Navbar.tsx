import Link from 'next/link';
import { Download, Sparkles } from 'lucide-react';

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 w-full border-b border-slate-100 bg-white/85 backdrop-blur-md transition-all">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center gap-2.5 group">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-600 text-white font-black shadow-md shadow-emerald-600/20 transition-transform group-hover:scale-105">
            L
          </div>
          <div className="flex flex-col">
            <span className="text-lg font-black tracking-tight text-slate-900">LAJU</span>
            <span className="text-[10px] font-bold text-emerald-600 tracking-widest uppercase -mt-1">
              Messenger
            </span>
          </div>
        </Link>

        {/* Navigation Links */}
        <nav className="hidden md:flex items-center gap-8 text-sm font-semibold text-slate-600">
          <Link href="/#features" className="hover:text-emerald-600 transition-colors">
            Keunggulan
          </Link>
          <Link href="/#why-laju" className="hover:text-emerald-600 transition-colors">
            Kenapa LAJU?
          </Link>
          <Link href="/download" className="hover:text-emerald-600 transition-colors">
            Download APK
          </Link>
        </nav>

        {/* CTA Buttons */}
        <div className="flex items-center gap-3">
          <Link
            href="/download"
            className="flex items-center gap-2 rounded-xl bg-emerald-600 px-4 py-2 text-xs font-bold text-white shadow-sm hover:bg-emerald-700 transition-all active:scale-95"
          >
            <Download className="h-4 w-4" />
            <span>Download Gratis</span>
          </Link>
        </div>
      </div>
    </header>
  );
}
