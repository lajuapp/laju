'use client';

import { 
  Headphones, 
  HelpCircle, 
  MessageSquare, 
  Key, 
  ArrowLeft, 
  CheckCircle2, 
  Mail, 
  ShieldCheck, 
  Smartphone, 
  Clock, 
  Wifi, 
  Send 
} from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export default function HelpPage() {
  const { t, locale } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>{t('help_back')}</span>
        </Link>

        {/* Hero Section of Help Page */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Manifesto Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              {t('help_hero_title_line1')}<br />
              {t('help_hero_title_line2')}
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              {t('help_hero_desc')}
            </p>

            {/* Core Support Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('help_guarantee1')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('help_guarantee2')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('help_guarantee3')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('help_guarantee4')}</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <a
                href="mailto:support@laju.chat"
                className="flex items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3 text-xs sm:text-sm font-semibold text-white shadow hover:bg-[#134E3E] transition-all"
              >
                <Mail className="h-4 w-4" />
                <span>{t('help_cta_contact')}</span>
              </a>
              <a
                href="#rincian-faq"
                className="flex items-center gap-2 rounded-full border border-stone-300 bg-white/80 px-5 py-3 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-white hover:text-slate-900 transition-all"
              >
                <span>{t('help_cta_faq')}</span>
              </a>
            </div>
          </div>

          {/* Right: User-provided Glassmorphic Phone Artwork */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white group">
              <img
                src="/images/bantuan-support.jpg"
                alt="LAJU Bantuan dan Dukungan Pelanggan"
                className="w-full h-auto object-cover transform group-hover:scale-[1.02] transition-transform duration-500 ease-out"
              />
              <div className="absolute bottom-4 inset-x-4 p-3.5 rounded-2xl bg-black/50 backdrop-blur-md border border-white/10 text-white text-xs flex items-center justify-between shadow-lg">
                <div className="flex items-center gap-2">
                  <Headphones className="h-4 w-4 text-emerald-400 shrink-0" />
                  <span className="font-semibold text-[11px] truncate">{t('help_image_badge_title')}</span>
                </div>
                <span className="text-[10px] uppercase font-bold text-emerald-300 bg-emerald-500/20 px-2 py-0.5 rounded-full shrink-0">
                  {t('help_status_active')}
                </span>
              </div>
            </div>
          </div>

        </div>

        {/* 4 Architectural Support Pillars */}
        <div className="mb-16 sm:mb-20 pt-12 border-t border-[#EAE8DE]">
          <div className="text-left mb-10">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('help_pillars_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-600">
              {t('help_pillars_sub')}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-10 text-left">
            {/* Pillar 1 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <HelpCircle className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('help_pillar1_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('help_pillar1_desc')}
              </p>
            </div>

            {/* Pillar 2 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <MessageSquare className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('help_pillar2_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('help_pillar2_desc')}
              </p>
            </div>

            {/* Pillar 3 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <Key className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('help_pillar3_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('help_pillar3_desc')}
              </p>
            </div>

            {/* Pillar 4 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <Mail className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('help_pillar4_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('help_pillar4_desc')}
              </p>
            </div>
          </div>
        </div>

        {/* Detailed FAQ & Help Articles */}
        <div id="rincian-faq" className="w-full space-y-10 text-left">
          
          <div className="border-b border-[#EAE8DE] pb-6">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('help_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('help_articles_sub')}
            </p>
          </div>

          <div className="space-y-12">
            {/* Section 1 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Smartphone className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_faq1_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('help_faq1_desc')}
              </p>
              <div className="text-xs text-slate-600 leading-relaxed pt-1">
                💡 <strong className="text-slate-900">{t('help_faq1_tip_label')}:</strong> {t('help_faq1_tip')}
              </div>
            </section>

            {/* Section 2 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Key className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_faq2_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('help_faq2_desc')}
              </p>
            </section>

            {/* Section 3 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Clock className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_faq3_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('help_faq3_desc')}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Wifi className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_faq4_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('help_faq4_desc')}
              </p>
            </section>

            {/* Section 5 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Send className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_faq5_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('help_faq5_desc')}
              </p>
            </section>

            {/* Contact Box */}
            <section className="space-y-4 pb-8">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Mail className="h-5 w-5 text-[#0D382C]" />
                <span>{t('help_contact_box_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('help_contact_box_desc')}
              </p>
              <div className="flex items-center gap-3 pt-1">
                <div className="p-3 rounded-xl bg-white border border-stone-200 text-xs font-mono text-slate-800 font-semibold shadow-2xs">
                  support@laju.chat
                </div>
                <a
                  href="mailto:support@laju.chat"
                  className="px-4 py-2.5 rounded-xl bg-[#0D382C] text-white text-xs font-bold hover:bg-[#134E3E] transition-colors"
                >
                  {t('help_send_email_btn')}
                </a>
              </div>
            </section>
          </div>

        </div>

      </div>
    </div>
  );
}
