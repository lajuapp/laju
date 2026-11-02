'use client';

import { EyeOff, Server, Key, Trash2, Download, HelpCircle } from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';
import { EditorialPageHero } from '@/components/EditorialPageHero';

export default function PrivacyPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        <EditorialPageHero
          titleLine1={t('privacy_hero_title_line1')}
          titleLine2={t('privacy_hero_title_line2')}
          description={t('privacy_hero_desc')}
          guarantees={[t('privacy_guarantee1'), t('privacy_guarantee2'), t('privacy_guarantee3'), t('privacy_guarantee4')]}
          image="/images/privacy-hero.jpg"
          imageAlt="LAJU Keamanan dan Perlindungan Privasi"
        >
          <Link
            href="/download"
            className="group inline-flex min-h-12 items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3 text-xs font-bold text-white shadow-[0_12px_28px_-10px_rgba(13,56,44,0.45)] transition-all duration-300 hover:-translate-y-0.5 hover:bg-[#134E3E] sm:text-sm"
          >
            <Download className="h-4 w-4 stroke-[2.5]" />
            <span>{t('privacy_cta_download')}</span>
          </Link>
          <a
            href="#rincian-kebijakan"
            className="inline-flex min-h-12 items-center gap-2 rounded-full border border-[#D8D6CC] bg-white/70 px-5 py-3 text-xs font-bold text-slate-700 transition-all duration-300 hover:-translate-y-0.5 hover:border-[#0D382C]/30 hover:bg-white sm:text-sm"
          >
            <span>{t('privacy_cta_details')}</span>
          </a>
        </EditorialPageHero>

        {/* Detailed Legal & Policy Articles */}
        <div id="rincian-kebijakan" className="mx-auto w-full max-w-5xl space-y-10 border-t border-[#EAE8DE] pt-12 text-left">
          
          <div className="border-b border-[#EAE8DE] pb-6">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('privacy_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('privacy_articles_sub')}
            </p>
          </div>

          <div className="space-y-0">
            {/* Section 1 */}
            <section className="space-y-4 border-b border-[#EAE8DE] py-7 first:pt-0">
              <h3 className="flex items-center gap-2.5 text-base font-bold text-slate-900 sm:text-lg">
                <Key className="h-5 w-5 text-laju-700" />
                <span>{t('privacy_sec1_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('privacy_sec1_lead')}
              </p>
              
              <ul className="space-y-2.5 pt-1 text-sm text-slate-600 leading-relaxed">
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec1_p1_title')}:</strong> {t('privacy_sec1_p1_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec1_p2_title')}:</strong> {t('privacy_sec1_p2_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec1_p3_title')}:</strong> {t('privacy_sec1_p3_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec1_p4_title')}:</strong> {t('privacy_sec1_p4_desc')}
                  </div>
                </li>
              </ul>
            </section>

            {/* Section 2 */}
            <section className="space-y-4 border-b border-[#EAE8DE] py-7">
              <h3 className="flex items-center gap-2.5 text-base font-bold text-slate-900 sm:text-lg">
                <EyeOff className="h-5 w-5 text-laju-700" />
                <span>{t('privacy_sec2_title')}</span>
              </h3>
              <ul className="space-y-3 pt-1 text-sm text-slate-600 leading-relaxed">
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec2_item1_title')}:</strong> {t('privacy_sec2_item1_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec2_item2_title')}:</strong> {t('privacy_sec2_item2_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec2_item3_title')}:</strong> {t('privacy_sec2_item3_desc')}
                  </div>
                </li>
                <li className="flex items-start gap-2.5">
                  <span className="text-slate-400 font-bold mt-0.5">•</span>
                  <div>
                    <strong className="text-slate-900">{t('privacy_sec2_item4_title')}:</strong> {t('privacy_sec2_item4_desc')}
                  </div>
                </li>
              </ul>
            </section>

            {/* Section 3 */}
            <section className="space-y-4 border-b border-[#EAE8DE] py-7">
              <h3 className="flex items-center gap-2.5 text-base font-bold text-slate-900 sm:text-lg">
                <Server className="h-5 w-5 text-laju-700" />
                <span>{t('privacy_sec3_title')}</span>
              </h3>
              <p className="max-w-4xl text-sm leading-relaxed text-slate-600 sm:text-base">
                {t('privacy_sec3_desc')}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-4 border-b border-[#EAE8DE] py-7">
              <h3 className="flex items-center gap-2.5 text-base font-bold text-slate-900 sm:text-lg">
                <Trash2 className="h-5 w-5 text-red-600" />
                <span>{t('privacy_sec4_title')}</span>
              </h3>
              <p className="max-w-4xl text-sm leading-relaxed text-slate-600 sm:text-base">
                {t('privacy_sec4_desc')}
              </p>
            </section>

            {/* Section 5 */}
            <section className="space-y-4 rounded-3xl border border-white/10 bg-[#0D382C] p-7 text-white shadow-[0_24px_60px_-36px_rgba(13,56,44,0.65)] sm:p-8">
              <h3 className="flex items-center gap-2.5 text-base font-bold text-white sm:text-lg">
                <HelpCircle className="h-5 w-5 text-[#B9DCC8]" />
                <span>{t('privacy_sec5_title')}</span>
              </h3>
              <p className="max-w-4xl text-sm leading-relaxed text-white/70 sm:text-base">
                {t('privacy_sec5_desc')}
              </p>
              <div className="flex flex-wrap items-center gap-3 pt-1">
                <div className="rounded-xl border border-white/15 bg-white/[0.07] px-4 py-2.5 font-mono text-xs font-semibold text-[#B9DCC8]">
                  support@laju.chat
                </div>
                <a
                  href="mailto:support@laju.chat"
                  className="rounded-xl bg-[#F5F4EF] px-5 py-2.5 text-xs font-bold text-[#0D382C] transition-all hover:-translate-y-0.5 hover:bg-white"
                >
                  {t('privacy_sec5_btn')}
                </a>
              </div>
            </section>
          </div>

        </div>

      </div>
    </div>
  );
}
