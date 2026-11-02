'use client';

import { HelpCircle, MessageSquare, Key, Mail, Smartphone, Clock, Wifi, Send } from 'lucide-react';
import { EditorialPageHero } from '@/components/EditorialPageHero';
import { useLanguage } from '@/context/LanguageContext';

export default function HelpPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        <EditorialPageHero
          titleLine1={t('help_hero_title_line1')}
          titleLine2={t('help_hero_title_line2')}
          description={t('help_hero_desc')}
          guarantees={[t('help_guarantee1'), t('help_guarantee2'), t('help_guarantee3'), t('help_guarantee4')]}
          image="/images/bantuan-support.jpg"
          imageAlt="LAJU Bantuan dan Dukungan Pelanggan"
        >
          <a
            href="mailto:support@laju.chat"
            className="group inline-flex min-h-12 items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3 text-xs font-bold text-white shadow-[0_12px_28px_-10px_rgba(13,56,44,0.45)] transition-all duration-300 hover:-translate-y-0.5 hover:bg-[#134E3E] sm:text-sm"
          >
            <Mail className="h-4 w-4" />
            <span>{t('help_cta_contact')}</span>
          </a>
          <a
            href="#rincian-faq"
            className="inline-flex min-h-12 items-center gap-2 rounded-full border border-[#D8D6CC] bg-white/70 px-5 py-3 text-xs font-bold text-slate-700 transition-all duration-300 hover:-translate-y-0.5 hover:border-[#0D382C]/30 hover:bg-white sm:text-sm"
          >
            <span>{t('help_cta_faq')}</span>
          </a>
        </EditorialPageHero>

        {/* Detailed FAQ */}
        <div id="rincian-faq" className="mx-auto w-full max-w-5xl space-y-10 border-t border-[#EAE8DE] pt-12 text-left">
          <div className="border-b border-[#EAE8DE] pb-6">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('help_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('help_articles_sub')}
            </p>
          </div>

          <div className="divide-y divide-[#EAE8DE]">
            {/* FAQ 1 */}
            <div className="py-7 first:pt-0 space-y-3">
              <h3 className="text-base sm:text-lg font-bold text-slate-900">
                {t('help_faq1_title')}
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed font-normal max-w-3xl">
                {t('help_faq1_desc')}
              </p>
              <div className="mt-3 pl-4 border-l-2 border-laju-500 py-1 text-xs sm:text-sm text-slate-600 leading-relaxed max-w-3xl">
                <strong className="text-slate-900 block mb-0.5">{t('help_faq1_tip_label')}</strong>
                {t('help_faq1_tip')}
              </div>
            </div>

            {/* FAQ 2 */}
            <div className="py-7 space-y-3">
              <h3 className="text-base sm:text-lg font-bold text-slate-900">
                {t('help_faq2_title')}
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed font-normal max-w-3xl">
                {t('help_faq2_desc')}
              </p>
            </div>

            {/* FAQ 3 */}
            <div className="py-7 space-y-3">
              <h3 className="text-base sm:text-lg font-bold text-slate-900">
                {t('help_faq3_title')}
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed font-normal max-w-3xl">
                {t('help_faq3_desc')}
              </p>
            </div>

            {/* FAQ 4 */}
            <div className="py-7 space-y-3">
              <h3 className="text-base sm:text-lg font-bold text-slate-900">
                {t('help_faq4_title')}
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed font-normal max-w-3xl">
                {t('help_faq4_desc')}
              </p>
            </div>

            {/* FAQ 5 */}
            <div className="py-7 last:pb-0 space-y-3">
              <h3 className="text-base sm:text-lg font-bold text-slate-900">
                {t('help_faq5_title')}
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed font-normal max-w-3xl">
                {t('help_faq5_desc')}
              </p>
            </div>
          </div>

          {/* Contact Box */}
          <div className="rounded-3xl border border-white/10 bg-[#0D382C] p-7 text-left text-white shadow-[0_24px_60px_-36px_rgba(13,56,44,0.65)] sm:p-8">
            <h3 className="text-xl font-bold mb-2">{t('help_contact_box_title')}</h3>
            <p className="mb-6 max-w-xl text-sm leading-relaxed text-white/70">
              {t('help_contact_box_desc')}
            </p>
            <div className="flex flex-wrap items-center gap-4">
              <div className="rounded-xl border border-white/15 bg-white/[0.07] px-4 py-2.5 font-mono text-sm font-bold text-[#B9DCC8]">
                support@laju.chat
              </div>
              <a
                href="mailto:support@laju.chat"
                className="inline-flex items-center gap-2 rounded-xl bg-[#F5F4EF] px-5 py-2.5 text-xs font-bold text-[#0D382C] transition-all hover:-translate-y-0.5 hover:bg-white sm:text-sm"
              >
                <Mail className="h-4 w-4" />
                <span>{t('help_send_email_btn')}</span>
              </a>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
