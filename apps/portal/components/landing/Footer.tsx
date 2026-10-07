import Link from 'next/link';

export function Footer() {
  return (
    <footer className="border-t border-[#EAE8DE] bg-[#F5F4EF] py-10 text-slate-600 text-xs">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-6">
          {/* Logo */}
          <Link href="/" className="text-xl font-black tracking-tight text-slate-900 font-sans">
            LAJU
          </Link>

          {/* Links */}
          <div className="flex items-center gap-6 font-medium text-slate-600">
            <Link href="/privacy" className="hover:text-slate-900 transition-colors">
              Privasi
            </Link>
            <Link href="/terms" className="hover:text-slate-900 transition-colors">
              Ketentuan
            </Link>
            <Link href="/#bantuan" className="hover:text-slate-900 transition-colors">
              Bantuan
            </Link>
          </div>

          {/* Copyright */}
          <div className="text-slate-500 text-[11px]">
            &copy; 2026 LAJU. Semua hak dilindungi.
          </div>
        </div>
      </div>
    </footer>
  );
}
