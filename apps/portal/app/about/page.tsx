'use client';

import { ExternalLink } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export default function AboutPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F8FAFC] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Editorial Header (No chip badge) */}
        <header className="space-y-4 mb-12 sm:mb-16 text-left max-w-4xl">
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-slate-900 tracking-tight leading-[1.08]">
            {t('about_hero_title')}
          </h1>

          <p className="text-lg sm:text-xl text-slate-600 leading-relaxed font-normal pt-2 max-w-3xl">
            {t('about_hero_lead')}
          </p>
        </header>

        {/* Atmospheric Scenery Image */}
        <figure className="mb-14 sm:mb-20">
          <div className="relative w-full rounded-[2rem] sm:rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white">
            <img
              src="/images/disappearing-lake.jpg"
              alt="LAJU - Ruang percakapan yang tenang"
              className="w-full h-72 sm:h-[420px] md:h-[500px] lg:h-[560px] object-cover object-center"
            />
          </div>
          <figcaption className="mt-3.5 text-xs sm:text-sm text-slate-500 italic text-left pl-1">
            {t('about_photo_caption')}
          </figcaption>
        </figure>

        {/* Editorial Prose Body */}
        <article className="space-y-12 sm:space-y-16 text-left max-w-4xl">
          
          {/* Section 1 */}
          <section className="space-y-4 pb-10 border-b border-slate-200">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('about_section1_title')}
            </h2>
            <div className="space-y-4 text-base sm:text-lg leading-relaxed text-slate-600 font-normal">
              <p>{t('about_section1_p1')}</p>
              <p>{t('about_section1_p2')}</p>
            </div>
          </section>

          {/* Section 2 */}
          <section className="space-y-4 pb-10 border-b border-slate-200">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('about_section2_title')}
            </h2>
            <div className="space-y-4 text-base sm:text-lg leading-relaxed text-slate-600 font-normal">
              <p>{t('about_section2_p1')}</p>
              <p>{t('about_section2_p2')}</p>
            </div>
          </section>

          {/* Core Principles */}
          <section className="space-y-6 pb-10 border-b border-slate-200 text-left">
            <div>
              <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
                {t('about_principles_title')}
              </h2>
              {t('about_principles_sub') && (
                <p className="mt-1.5 text-xs sm:text-sm text-slate-600">
                  {t('about_principles_sub')}
                </p>
              )}
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 text-left pt-2">
              <div className="space-y-2">
                <h3 className="text-base sm:text-lg font-bold text-slate-900">{t('about_principle1_title')}</h3>
                <p className="text-sm text-slate-600 leading-relaxed font-normal">
                  {t('about_principle1_desc')}
                </p>
              </div>

              <div className="space-y-2">
                <h3 className="text-base sm:text-lg font-bold text-slate-900">{t('about_principle2_title')}</h3>
                <p className="text-sm text-slate-600 leading-relaxed font-normal">
                  {t('about_principle2_desc')}
                </p>
              </div>

              <div className="space-y-2">
                <h3 className="text-base sm:text-lg font-bold text-slate-900">{t('about_principle3_title')}</h3>
                <p className="text-sm text-slate-600 leading-relaxed font-normal">
                  {t('about_principle3_desc')}
                </p>
              </div>
            </div>
          </section>

          {/* Open Source Callout */}
          <section className="p-8 sm:p-10 rounded-3xl bg-slate-900 text-white shadow-xl space-y-4">
            <h3 className="text-2xl font-bold">{t('about_open_source_title')}</h3>
            <p className="text-sm sm:text-base text-slate-300 leading-relaxed max-w-2xl font-normal">
              {t('about_open_source_closing')}
            </p>
            <div className="pt-2">
              <a
                href="https://github.com/lajuapp/laju"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 rounded-full bg-laju-500 hover:bg-laju-600 px-6 py-3 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow transition-all active:scale-95"
              >
                <span>{t('about_github_link_text')}</span>
                <ExternalLink className="h-4 w-4" />
              </a>
            </div>
          </section>

        </article>

      </div>
    </div>
  );
}
