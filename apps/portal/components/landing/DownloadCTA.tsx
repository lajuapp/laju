'use client';

import Link from 'next/link';
import { Smartphone, ChevronRight } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function DownloadCTA() {
  const { t } = useLanguage();

  return (
    <section className="py-20 sm:py-28 bg-[#F8FAFC] border-t border-slate-200 relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Copy & Actions (No chip badge) */}
          <div className="lg:col-span-5 space-y-6 text-left">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-black text-slate-900 tracking-tight leading-[1.1]">
              {t('cta_title_line1')}<br />
              <span className="text-laju-700">{t('cta_title_line2')}</span>
            </h2>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal">
              {t('cta_subtitle_line1')}<br />
              {t('cta_subtitle_line2')}
            </p>

            <div className="pt-2 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2.5 rounded-full bg-laju-500 hover:bg-laju-600 px-7 py-3.5 text-sm font-bold text-slate-950 shadow-mint-glow hover:shadow-mint-glow-sm transition-all active:scale-95"
              >
                <Smartphone className="h-4 w-4 stroke-[2.5]" />
                <span>{t('cta_download_btn')}</span>
              </Link>

              <a
                href="#fitur"
                className="flex items-center gap-2 rounded-full border border-slate-300 bg-white px-6 py-3.5 text-sm font-bold text-slate-700 hover:text-slate-950 hover:bg-slate-50 transition-all shadow-xs"
              >
                <span>{t('cta_monitor_btn')}</span>
                <ChevronRight className="h-4 w-4" />
              </a>
            </div>
          </div>

          {/* Right Column: Real Laptop + Smartphone Workspace Photo */}
          <div className="lg:col-span-7 flex justify-center items-center">
            <div className="relative w-full rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white">
              <img
                src="/images/cta-devices.jpg"
                alt="LAJU di Berbagai Perangkat"
                className="w-full h-auto object-cover transform hover:scale-[1.01] transition-transform duration-500 ease-out"
              />
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
