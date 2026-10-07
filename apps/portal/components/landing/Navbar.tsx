import Link from 'next/link';
import { Moon, ChevronDown } from 'lucide-react';

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 w-full bg-[#F5F4EF]/90 backdrop-blur-md transition-all">
      <div className="mx-auto flex h-20 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center">
          <span className="text-2xl font-black tracking-tight text-slate-900 font-sans">
            LAJU
          </span>
        </Link>

        {/* Center Nav Links */}
        <nav className="hidden md:flex items-center gap-1 sm:gap-2 text-sm">
          <Link
            href="/"
            className="px-4 py-1.5 rounded-full bg-slate-200/70 font-semibold text-slate-900 text-xs sm:text-sm"
          >
            Beranda
          </Link>
          <Link
            href="/#fitur"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            Fitur
          </Link>
          <Link
            href="/privacy"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            Privasi
          </Link>
          <Link
            href="/#bantuan"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            Bantuan
          </Link>
        </nav>

        {/* Right Actions: Moon, Language, Unduh button */}
        <div className="flex items-center gap-4">
          <button
            type="button"
            className="text-slate-600 hover:text-slate-900 p-1.5 rounded-full transition-colors"
            aria-label="Toggle theme"
          >
            <Moon className="h-4 w-4" />
          </button>

          <div className="flex items-center gap-1 text-xs font-semibold text-slate-700 cursor-pointer">
            <span>ID</span>
            <ChevronDown className="h-3 w-3 text-slate-500" />
          </div>

          <Link
            href="/download"
            className="flex items-center justify-center rounded-xl bg-[#0D382C] px-5 py-2.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
          >
            Unduh
          </Link>
        </div>
      </div>
    </header>
  );
}
