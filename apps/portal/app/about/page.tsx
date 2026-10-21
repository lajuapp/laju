'use client';

import { 
  ArrowLeft, 
  ExternalLink, 
  ShieldCheck,
  Compass,
  HeartHandshake
} from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export default function AboutPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 sm:mb-10 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>{t('about_back')}</span>
        </Link>

        {/* Editorial Header */}
        <header className="space-y-4 mb-12 sm:mb-16 text-left max-w-4xl">
          <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">
            {t('about_hero_tag')}
          </p>

          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-slate-900 tracking-tight leading-[1.08]">
            {t('about_hero_title')}
          </h1>

          <p className="text-lg sm:text-xl text-slate-700 leading-relaxed font-normal pt-2 max-w-3xl">
            {t('about_hero_lead')}
          </p>
        </header>

        {/* Serene Atmosphere Image */}
        <figure className="mb-14 sm:mb-20">
          <div className="relative w-full rounded-[2rem] sm:rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white">
            <img
              src="/images/disappearing-lake.jpg"
              alt="LAJU - Ruang yang tenang"
              className="w-full h-72 sm:h-[420px] md:h-[500px] lg:h-[560px] object-cover object-center"
            />
          </div>
          <figcaption className="mt-3.5 text-xs sm:text-sm text-slate-500 italic text-left pl-1">
            {t('about_photo_caption')}
          </figcaption>
        </figure>

        {/* Editorial Prose Body */}
        <article className="space-y-12 sm:space-y-16 text-left text-slate-700">
          
          {/* Section 1 */}
          <section className="space-y-4 max-w-4xl">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('about_section1_title')}
            </h2>
            <div className="space-y-4 text-base sm:text-lg leading-relaxed text-slate-600">
              <p>{t('about_section1_p1')}</p>
              <p>{t('about_section1_p2')}</p>
            </div>
          </section>

          {/* Section 2 */}
          <section className="space-y-4 max-w-4xl">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('about_section2_title')}
            </h2>
            <div className="space-y-4 text-base sm:text-lg leading-relaxed text-slate-600">
              <p>{t('about_section2_p1')}</p>
              <p>{t('about_section2_p2')}</p>
            </div>
          </section>

          {/* Core Principles */}
          <section className="pt-12 sm:pt-16 border-t border-[#EAE8DE] text-left">
            <div className="mb-10">
              <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
                {t('about_principles_title')}
              </h2>
              {t('about_principles_sub') && (
                <p className="mt-1.5 text-xs sm:text-sm text-slate-600">
                  {t('about_principles_sub')}
                </p>
              )}
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8 lg:gap-10 text-left">
              {/* Principle 1 */}
              <div className="space-y-3">
                <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                  <ShieldCheck className="h-5 w-5" />
                </div>
                <h3 className="text-base font-bold text-slate-900">
                  {t('about_principle1_title').replace(/^\d+\.\s*/, '')}
                </h3>
                <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                  {t('about_principle1_desc')}
                </p>
              </div>

              {/* Principle 2 */}
              <div className="space-y-3">
                <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                  <Compass className="h-5 w-5" />
                </div>
                <h3 className="text-base font-bold text-slate-900">
                  {t('about_principle2_title').replace(/^\d+\.\s*/, '')}
                </h3>
                <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                  {t('about_principle2_desc')}
                </p>
              </div>

              {/* Principle 3 */}
              <div className="space-y-3">
                <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                  <HeartHandshake className="h-5 w-5" />
                </div>
                <h3 className="text-base font-bold text-slate-900">
                  {t('about_principle3_title').replace(/^\d+\.\s*/, '')}
                </h3>
                <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                  {t('about_principle3_desc')}
                </p>
              </div>
            </div>
          </section>

          {/* Open Source & GitHub Note */}
          <section className="pt-10 sm:pt-12 border-t border-[#EAE8DE] space-y-4 pb-8 text-left">
            <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
              <svg className="h-5 w-5 fill-[#0D382C]" viewBox="0 0 24 24">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
              </svg>
              <span>{t('about_open_source_title')}</span>
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
              {t('about_open_source_closing')}
            </p>
            <div className="flex flex-wrap items-center gap-3 pt-1">
              <div className="p-3 rounded-xl bg-white border border-stone-200 text-xs font-mono text-slate-800 font-semibold shadow-2xs">
                github.com/lajuapp/laju
              </div>
              <a
                href="https://github.com/lajuapp/laju"
                target="_blank"
                rel="noopener noreferrer"
                className="px-4 py-2.5 rounded-xl bg-[#0D382C] text-white text-xs font-bold hover:bg-[#134E3E] transition-colors inline-flex items-center gap-1.5"
              >
                <span>{t('about_github_link_text')}</span>
                <ExternalLink className="h-3.5 w-3.5" />
              </a>
            </div>
          </section>

        </article>

      </div>
    </div>
  );
}
