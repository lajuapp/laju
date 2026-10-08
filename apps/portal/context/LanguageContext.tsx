'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';
import { Locale, translations, TranslationKey, supportedLocales } from '@/lib/i18n/translations';

interface LanguageContextType {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  toggleLocale: () => void;
  t: (key: TranslationKey) => string;
}

const LanguageContext = createContext<LanguageContextType>({
  locale: 'id',
  setLocale: () => {},
  toggleLocale: () => {},
  t: (key: TranslationKey) => translations.id[key] || (key as string),
});

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>('id');
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    try {
      const saved = localStorage.getItem('laju_locale') as Locale | null;
      const valid = supportedLocales.some((l) => l.code === saved);
      if (saved && valid) {
        setLocaleState(saved);
        document.documentElement.lang = saved;
      } else {
        document.documentElement.lang = 'id';
      }
    } catch (_) {}
    setMounted(true);
  }, []);

  const setLocale = (newLocale: Locale) => {
    setLocaleState(newLocale);
    try {
      localStorage.setItem('laju_locale', newLocale);
      document.documentElement.lang = newLocale;
    } catch (_) {}
  };

  const toggleLocale = () => {
    const list: Locale[] = ['id', 'en', 'ru', 'ja', 'zh'];
    const nextIdx = (list.indexOf(locale) + 1) % list.length;
    setLocale(list[nextIdx]);
  };

  const t = (key: TranslationKey): string => {
    const dict = (translations[locale] || translations.id) as Record<string, string>;
    const defaultDict = translations.id as Record<string, string>;
    return dict[key] || defaultDict[key] || (key as string);
  };

  return (
    <LanguageContext.Provider value={{ locale, setLocale, toggleLocale, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  return useContext(LanguageContext);
}
