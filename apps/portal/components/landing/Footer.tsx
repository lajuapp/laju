'use client';

import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export function Footer() {
  const { t } = useLanguage();

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
              {t('footer_privacy')}
            </Link>
            <Link href="/terms" className="hover:text-slate-900 transition-colors">
              {t('footer_terms')}
            </Link>
            <Link href="/help" className="hover:text-slate-900 transition-colors">
              {t('footer_help')}
            </Link>
          </div>

          {/* Copyright */}
          <div className="text-slate-500 text-[11px]">
            {t('footer_copyright')}
          </div>
        </div>
      </div>
    </footer>
  );
}
