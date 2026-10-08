'use client';

import { useLanguage } from '@/context/LanguageContext';

export function DisappearingMessagesSection() {
  const { t } = useLanguage();

  return (
    <section className="relative min-h-[520px] lg:min-h-[600px] flex items-center overflow-hidden text-white">
      {/* Twilight Alpine Lake Background Photo */}
      <img
        src="/images/disappearing-lake.jpg"
        alt="Ruang yang tetap terjaga di tepi danau senja"
        className="absolute inset-0 w-full h-full object-cover object-[70%_center] lg:object-center"
      />

      {/* Dark gradient overlay to guarantee text legibility on the left side */}
      <div className="absolute inset-0 bg-gradient-to-r from-slate-950/90 via-slate-950/50 to-transparent lg:w-3/5" />
      <div className="absolute inset-0 bg-slate-950/20" />

      <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-20 sm:py-28 w-full">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          
          {/* Left Column: Headline and Philosophy */}
          <div className="lg:col-span-6 space-y-6 text-left max-w-xl">
            <p className="text-xs font-bold text-emerald-400 uppercase tracking-widest">
              {t('disappear_tag')}
            </p>

            <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white tracking-tight leading-[1.08]">
              {t('disappear_title_line1')}<br />
              {t('disappear_title_line2')}
            </h2>

            <p className="text-slate-200 text-base sm:text-lg leading-relaxed font-normal">
              {t('disappear_desc')}
            </p>
          </div>

          {/* Right Column: Natural space showcasing the phone on the lakeside rock */}
          <div className="lg:col-span-6 hidden lg:block" />

        </div>
      </div>
    </section>
  );
}
