'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { ChevronDown, Globe, Download } from 'lucide-react';
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
    <header className="sticky top-0 z-50 w-full bg-[#F8FAFC]/90 backdrop-blur-md border-b border-slate-200/60 transition-all">
      <div className="mx-auto flex h-20 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center gap-3 group">
          <div className="relative h-10 w-10 overflow-hidden rounded-xl bg-slate-900 p-0.5 shadow-sm group-hover:scale-105 transition-transform duration-200">
            <Image
              src="/images/logo_icon.png"
              alt="LAJU Messenger"
              width={40}
              height={40}
              className="h-full w-full object-contain"
              priority
            />
          </div>
          <span className="text-2xl font-black tracking-tight text-slate-900 font-sans">
            LAJU
          </span>
        </Link>

        {/* Center Nav Links */}
        <nav className="hidden md:flex items-center gap-1 sm:gap-2 text-sm">
          <Link
            href="/"
            className="px-3.5 py-1.5 rounded-full text-slate-700 hover:text-slate-900 hover:bg-slate-200/60 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_home')}
          </Link>
          <Link
            href="/#fitur"
            className="px-3.5 py-1.5 rounded-full text-slate-600 hover:text-slate-900 hover:bg-slate-200/60 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_features')}
          </Link>
          <Link
            href="/privacy"
            className="px-3.5 py-1.5 rounded-full text-slate-600 hover:text-slate-900 hover:bg-slate-200/60 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_privacy')}
          </Link>
          <Link
            href="/help"
            className="px-3.5 py-1.5 rounded-full text-slate-600 hover:text-slate-900 hover:bg-slate-200/60 font-medium text-xs sm:text-sm transition-colors"
          >
            {t('nav_help')}
          </Link>
          <Link
            href="/about"
            className="px-3.5 py-1.5 rounded-full text-slate-600 hover:text-slate-900 hover:bg-slate-200/60 font-medium text-xs sm:text-sm transition-colors"
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
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-xs font-bold text-slate-800 transition-all shadow-xs"
              aria-label="Pilih Bahasa"
            >
              <Globe className="h-3.5 w-3.5 text-slate-500" />
              <span>{locale.toUpperCase()}</span>
              <ChevronDown className={`h-3 w-3 text-slate-500 transition-transform ${langMenuOpen ? 'rotate-180' : ''}`} />
            </button>

            {langMenuOpen && (
              <div className="absolute right-0 mt-2 w-44 rounded-2xl bg-white p-1.5 shadow-xl border border-slate-200 z-50 text-xs animate-in fade-in zoom-in-95 duration-100">
                {supportedLocales.map((item) => (
                  <button
                    key={item.code}
                    type="button"
                    onClick={() => {
                      setLocale(item.code);
                      setLangMenuOpen(false);
                    }}
                    className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-left transition-colors font-medium ${
                      locale === item.code ? 'bg-laju-50 text-laju-800 font-bold' : 'text-slate-700 hover:bg-slate-100'
                    }`}
                  >
                    <span className="flex items-center gap-2">
                      <span className="text-sm">{item.flag}</span>
                      <span>{item.name}</span>
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Unduh Action Button */}
          <Link
            href="/download"
            className="flex items-center gap-1.5 rounded-full bg-laju-500 hover:bg-laju-600 px-4 sm:px-5 py-2 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow-sm hover:shadow-mint-glow transition-all active:scale-95"
          >
            <Download className="h-3.5 w-3.5 stroke-[2.5]" />
            <span>{t('nav_download')}</span>
          </Link>
        </div>
      </div>
    </header>
  );
}
