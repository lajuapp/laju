'use client';

import { 
  FileText, 
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
    <div className="py-12 sm:py-20 bg-[#F8FAFC] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Hero Section of Terms Page */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-slate-900 tracking-tight leading-[1.08]">
              {t('terms_hero_title_line1')}<br />
              <span className="text-laju-700">{t('terms_hero_title_line2')}</span>
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              {t('terms_hero_desc')}
            </p>

            {/* Core Terms Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('terms_guarantee1')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('terms_guarantee2')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('terms_guarantee3')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('terms_guarantee4')}</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2 rounded-full bg-laju-500 hover:bg-laju-600 px-6 py-3 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow transition-all"
              >
                <Download className="h-4 w-4 stroke-[2.5]" />
                <span>{t('terms_cta_download')}</span>
              </Link>
              <a
                href="#rincian-ketentuan"
                className="flex items-center gap-2 rounded-full border border-slate-300 bg-white px-5 py-3 text-xs sm:text-sm font-bold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-xs"
              >
                <span>{t('terms_cta_details')}</span>
              </a>
            </div>
          </div>

          {/* Right: Real Editorial Photo */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white group">
              <img
                src="/images/security-notebook.jpg"
                alt="LAJU Ketentuan Layanan yang Adil"
                className="w-full h-auto object-cover transform group-hover:scale-[1.02] transition-transform duration-500 ease-out"
              />
              <div className="absolute bottom-4 inset-x-4 p-3.5 rounded-2xl bg-black/50 backdrop-blur-md border border-white/10 text-white text-xs flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Scale className="h-3.5 w-3.5 text-laju-400" />
                  <span className="font-semibold text-[11px]">{t('terms_badge')}</span>
                </div>
                <span className="text-[10px] uppercase font-bold text-emerald-300 bg-emerald-500/20 px-2 py-0.5 rounded-full shrink-0">
                  AGPLv3
                </span>
              </div>
            </div>
          </div>

        </div>

        {/* Detailed Legal & Terms Articles */}
        <div id="rincian-ketentuan" className="w-full space-y-10 text-left pt-12 border-t border-slate-200">
          
          <div className="border-b border-slate-200 pb-6">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('terms_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('terms_articles_sub')}
            </p>
          </div>

          <div className="space-y-12">
            {/* Section 1 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <FileText className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec1_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec1_body')}
              </p>
            </section>

            {/* Section 2 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Key className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec2_title')}</span>
              </h3>
              <p className="text-sm sm:text-base text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec2_body')}
              </p>
            </section>

            {/* Section 3 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Lock className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec3_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec3_body')}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <AlertTriangle className="h-5 w-5 text-amber-600" />
                <span>{t('terms_sec4_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec4_body')}
              </p>
            </section>

            {/* Section 5 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Server className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec5_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec5_body')}
              </p>
            </section>

            {/* Section 6 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <ShieldCheck className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec6_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec6_body')}
              </p>
            </section>

            {/* Section 7 */}
            <section className="space-y-4 pb-8">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <HelpCircle className="h-5 w-5 text-laju-700" />
                <span>{t('terms_sec7_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('terms_sec7_body')}
              </p>
              <div className="flex items-center gap-3 pt-1">
                <div className="px-4 py-2.5 rounded-xl bg-white border border-slate-200 text-xs font-mono text-slate-800 font-semibold">
                  support@laju.chat
                </div>
                <a
                  href="mailto:support@laju.chat"
                  className="px-5 py-2.5 rounded-xl bg-slate-900 text-white text-xs font-bold hover:bg-slate-800 transition-colors"
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
