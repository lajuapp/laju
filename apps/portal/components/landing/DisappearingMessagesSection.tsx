'use client';

import { useLanguage } from '@/context/LanguageContext';

export function DisappearingMessagesSection() {
  const { t } = useLanguage();

  return (
    <section className="relative min-h-[520px] lg:min-h-[600px] flex items-center overflow-hidden text-white">
      {/* Twilight Lake Background Photo */}
      <img
        src="/images/disappearing-lake.jpg"
        alt="Ruang yang tetap privat di tepi danau senja"
        className="absolute inset-0 w-full h-full object-cover object-[70%_center] lg:object-center"
      />

      {/* Dark gradient overlay to guarantee text legibility on the left side */}
      <div className="absolute inset-0 bg-gradient-to-r from-slate-950/90 via-slate-950/60 to-transparent lg:w-3/5" />
      <div className="absolute inset-0 bg-slate-950/25" />

      <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-20 sm:py-28 w-full">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          
          {/* Left Column: Headline and Philosophy (No chip badge) */}
          <div className="lg:col-span-6 space-y-6 text-left max-w-xl">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-black text-white tracking-tight leading-[1.1]">
              {t('disappear_title_line1')}<br />
              <span className="text-laju-400">{t('disappear_title_line2')}</span>
            </h2>

            <p className="text-slate-200 text-base sm:text-lg leading-relaxed font-normal">
              {t('disappear_desc')}
            </p>
          </div>

          {/* Right Column: Natural space showcasing the lake scenery */}
          <div className="lg:col-span-6 hidden lg:block" />

        </div>
      </div>
    </section>
  );
}
