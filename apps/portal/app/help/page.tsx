'use client';

import { 
  Headphones, 
  HelpCircle, 
  MessageSquare, 
  Key, 
  CheckCircle2, 
  Mail, 
  Smartphone, 
  Clock, 
  Wifi, 
  Send 
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export default function HelpPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F8FAFC] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Hero Section of Help Page (No chip badge) */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-slate-900 tracking-tight leading-[1.08]">
              {t('help_hero_title_line1')}<br />
              <span className="text-laju-700">{t('help_hero_title_line2')}</span>
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              {t('help_hero_desc')}
            </p>

            {/* Core Support Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('help_guarantee1')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('help_guarantee2')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('help_guarantee3')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('help_guarantee4')}</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <a
                href="mailto:support@laju.chat"
                className="flex items-center gap-2 rounded-full bg-laju-500 hover:bg-laju-600 px-6 py-3 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow transition-all"
              >
                <Mail className="h-4 w-4" />
                <span>{t('help_cta_contact')}</span>
              </a>
              <a
                href="#rincian-faq"
                className="flex items-center gap-2 rounded-full border border-slate-300 bg-white px-5 py-3 text-xs sm:text-sm font-bold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-xs"
              >
                <span>{t('help_cta_faq')}</span>
              </a>
            </div>
          </div>

          {/* Right: User Support Artwork */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white group">
              <img
                src="/images/bantuan-support.jpg"
                alt="LAJU Bantuan dan Dukungan Pelanggan"
                className="w-full h-auto object-cover transform group-hover:scale-[1.02] transition-transform duration-500 ease-out"
              />
              <div className="absolute bottom-4 inset-x-4 p-3.5 rounded-2xl bg-black/50 backdrop-blur-md border border-white/10 text-white text-xs flex items-center justify-between shadow-lg">
                <div className="flex items-center gap-2">
                  <Headphones className="h-4 w-4 text-laju-400 shrink-0" />
                  <span className="font-semibold text-[11px] truncate">{t('help_image_badge_title')}</span>
                </div>
                <span className="text-[10px] uppercase font-bold text-emerald-300 bg-emerald-500/20 px-2 py-0.5 rounded-full shrink-0">
                  {t('help_status_active')}
                </span>
              </div>
            </div>
          </div>

        </div>

        {/* Detailed FAQ */}
        <div id="rincian-faq" className="w-full space-y-8 text-left pt-12 border-t border-slate-200">
          <div className="border-b border-slate-200 pb-6">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('help_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('help_articles_sub')}
            </p>
          </div>

          <div className="divide-y divide-slate-200/80">
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
          <div className="mt-12 p-8 rounded-3xl bg-slate-900 text-white text-left shadow-lg">
            <h3 className="text-xl font-bold mb-2">{t('help_contact_box_title')}</h3>
            <p className="text-sm text-slate-300 leading-relaxed mb-6 max-w-xl">
              {t('help_contact_box_desc')}
            </p>
            <div className="flex flex-wrap items-center gap-4">
              <div className="px-4 py-2.5 rounded-xl bg-slate-800 border border-slate-700 text-sm font-mono text-emerald-400 font-bold">
                support@laju.chat
              </div>
              <a
                href="mailto:support@laju.chat"
                className="inline-flex items-center gap-2 rounded-xl bg-laju-500 hover:bg-laju-600 px-5 py-2.5 text-xs sm:text-sm font-bold text-slate-950 transition-all shadow-mint-glow"
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
