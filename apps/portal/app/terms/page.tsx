'use client';

import { 
  FileText, 
  ArrowLeft, 
  CheckCircle2, 
  Scale, 
  Key, 
  Lock, 
  ShieldCheck, 
  AlertTriangle, 
  Trash2, 
  HelpCircle, 
  Download,
  Server
} from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export default function TermsPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>{t('terms_back')}</span>
        </Link>

        {/* Hero Section of Terms Page */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Manifesto Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-4 py-1.5 text-xs font-bold text-stone-700 shadow-sm">
              <Scale className="h-4 w-4 text-[#0D382C]" />
              <span>{t('terms_badge')}</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-slate-900 tracking-tight leading-[1.08]">
              {t('terms_hero_title_line1')}<br />
              {t('terms_hero_title_line2')}
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              {t('terms_hero_desc')}
            </p>

            {/* Core Terms Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('terms_guarantee1')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('terms_guarantee2')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('terms_guarantee3')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-[#0D382C] shrink-0" />
                <span>{t('terms_guarantee4')}</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2 rounded-full bg-[#0D382C] px-6 py-3 text-xs sm:text-sm font-semibold text-white shadow hover:bg-[#134E3E] transition-all"
              >
                <Download className="h-4 w-4" />
                <span>{t('terms_cta_download')}</span>
              </Link>
              <a
                href="#rincian-ketentuan"
                className="flex items-center gap-2 rounded-full border border-stone-300 bg-white/80 px-5 py-3 text-xs sm:text-sm font-semibold text-slate-700 hover:bg-white hover:text-slate-900 transition-all"
              >
                <span>{t('terms_cta_details')}</span>
              </a>
            </div>
          </div>

          {/* Right: Visual Illustration Card */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white p-8 space-y-6">
              <div className="h-14 w-14 rounded-2xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-[#0D382C]">
                <ShieldCheck className="h-7 w-7" />
              </div>
              <div>
                <h3 className="text-xl font-extrabold text-slate-900">{t('terms_card_title')}</h3>
                <p className="mt-2 text-xs text-slate-600 leading-relaxed">
                  {t('terms_card_desc')}
                </p>
              </div>
              <div className="space-y-3 pt-2 border-t border-stone-100 text-xs text-slate-700 font-medium">
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>{t('terms_card_f1_label')}</span>
                  <span className="font-bold text-emerald-700">{t('terms_card_f1_val')}</span>
                </div>
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>{t('terms_card_f2_label')}</span>
                  <span className="font-bold text-emerald-700">{t('terms_card_f2_val')}</span>
                </div>
                <div className="flex items-center justify-between py-1.5 px-3 rounded-xl bg-stone-50">
                  <span>{t('terms_card_f3_label')}</span>
                  <span className="font-bold text-emerald-700">{t('terms_card_f3_val')}</span>
                </div>
              </div>
            </div>
          </div>

        </div>

        {/* 4 Core Pillars */}
        <div className="mb-16 sm:mb-20 pt-12 border-t border-[#EAE8DE]">
          <div className="text-left mb-10">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('terms_pillars_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-600">
              {t('terms_pillars_sub')}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-10 text-left">
            {/* Pillar 1 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <Key className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('terms_pillar1_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('terms_pillar1_desc')}
              </p>
            </div>

            {/* Pillar 2 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <Lock className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('terms_pillar2_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('terms_pillar2_desc')}
              </p>
            </div>

            {/* Pillar 3 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <AlertTriangle className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('terms_pillar3_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('terms_pillar3_desc')}
              </p>
            </div>

            {/* Pillar 4 */}
            <div className="space-y-3">
              <div className="h-10 w-10 rounded-xl bg-[#0D382C]/8 flex items-center justify-center text-[#0D382C]">
                <Trash2 className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">{t('terms_pillar4_title')}</h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('terms_pillar4_desc')}
              </p>
            </div>
          </div>
        </div>

        {/* Detailed Legal & Terms Articles */}
        <div id="rincian-ketentuan" className="w-full space-y-10 text-left">
          
          <div className="border-b border-[#EAE8DE] pb-6">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              {t('terms_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('terms_articles_sub')}
            </p>
          </div>

          <div className="space-y-12">
            {/* Section 1 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <FileText className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec1_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec1_body')}
              </p>
            </section>

            {/* Section 2 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Key className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec2_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec2_body')}
              </p>
            </section>

            {/* Section 3 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Lock className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec3_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec3_body')}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <AlertTriangle className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec4_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec4_body')}
              </p>
            </section>

            {/* Section 5 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Server className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec5_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec5_body')}
              </p>
            </section>

            {/* Section 6 */}
            <section className="space-y-4 pb-8 border-b border-[#EAE8DE]">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <ShieldCheck className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec6_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec6_body')}
              </p>
            </section>

            {/* Section 7 */}
            <section className="space-y-4 pb-8">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <HelpCircle className="h-5 w-5 text-[#0D382C]" />
                <span>{t('terms_sec7_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec7_body')}
              </p>
              <div className="flex items-center gap-3 pt-1">
                <div className="p-3 rounded-xl bg-white border border-stone-200 text-xs font-mono text-slate-800 font-semibold shadow-2xs">
                  support@laju.chat
                </div>
                <a
                  href="mailto:support@laju.chat"
                  className="px-4 py-2.5 rounded-xl bg-[#0D382C] text-white text-xs font-bold hover:bg-[#134E3E] transition-colors"
                >
                  {t('help_send_email_btn') || 'Kirim Email Support'}
                </a>
              </div>
            </section>
          </div>

        </div>

      </div>
    </div>
  );
}
