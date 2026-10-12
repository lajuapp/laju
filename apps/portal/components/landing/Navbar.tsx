'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { ChevronDown, Check, Globe } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';
import { supportedLocales } from '@/lib/i18n/translations';

export function Navbar() {
  const { locale, setLocale, t } = useLanguage();
  const [langMenuOpen, setLangMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setLangMenuOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

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
            className="px-4 py-1.5 rounded-full hover:bg-slate-200/70 font-semibold text-slate-900 text-xs sm:text-sm transition-colors"
          >
            {t('nav_home')}
          </Link>
          <Link
            href="/#fitur"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_features')}
          </Link>
          <Link
            href="/privacy"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_privacy')}
          </Link>
          <Link
            href="/help"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_help')}
          </Link>
          <Link
            href="/about"
            className="px-4 py-1.5 rounded-full text-slate-600 hover:text-slate-900 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_about')}
          </Link>
        </nav>

        {/* Right Actions: Language Switcher, Unduh button */}
        <div className="flex items-center gap-3 sm:gap-4">
          {/* Language Switcher Dropdown */}
          <div className="relative" ref={menuRef}>
            <button
              type="button"
              onClick={() => setLangMenuOpen(!langMenuOpen)}
              className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-stone-200 bg-white/70 hover:bg-white text-xs font-bold text-slate-800 transition-all shadow-xs"
              aria-label="Pilih Bahasa"
            >
              <Globe className="h-3.5 w-3.5 text-slate-500" />
              <span>{locale.toUpperCase()}</span>
              <ChevronDown className={`h-3 w-3 text-slate-500 transition-transform ${langMenuOpen ? 'rotate-180' : ''}`} />
            </button>

            {langMenuOpen && (
              <div className="absolute right-0 mt-2 w-44 rounded-2xl bg-white p-1.5 shadow-xl border border-stone-200 z-50 text-xs animate-in fade-in zoom-in-95 duration-100">
                {supportedLocales.map((item) => (
                  <button
                    key={item.code}
                    type="button"
                    onClick={() => {
                      setLocale(item.code);
                      setLangMenuOpen(false);
                    }}
                    className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-left transition-colors font-medium ${
                      locale === item.code ? 'bg-[#0D382C]/10 text-[#0D382C] font-bold' : 'text-slate-700 hover:bg-stone-100'
                    }`}
                  >
                    <span className="flex items-center gap-2">
                      <span className="text-sm">{item.flag}</span>
                      <span>{item.name}</span>
                    </span>
                    {locale === item.code && <Check className="h-3.5 w-3.5 text-[#0D382C]" />}
                  </button>
                ))}
              </div>
            )}
          </div>

          <Link
            href="/download"
            className="flex items-center justify-center rounded-xl bg-[#0D382C] px-5 py-2.5 text-xs sm:text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
          >
            {t('nav_download')}
          </Link>
        </div>
      </div>
    </header>
  );
}
