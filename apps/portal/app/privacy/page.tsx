'use client';

import { 
  Lock, 
  EyeOff, 
  Server, 
  CheckCircle2, 
  Key, 
  Trash2, 
  Download, 
  HelpCircle 
} from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export default function PrivacyPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F8FAFC] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Hero Section of Privacy Page (No chip badge) */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center mb-16 sm:mb-24">
          
          {/* Left: Copy */}
          <div className="lg:col-span-7 space-y-6 text-left">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-slate-900 tracking-tight leading-[1.08]">
              {t('privacy_hero_title_line1')}<br />
              <span className="text-laju-700">{t('privacy_hero_title_line2')}</span>
            </h1>

            <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal max-w-2xl">
              {t('privacy_hero_desc')}
            </p>

            {/* Core Privacy Guarantees */}
            <div className="pt-2 grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold text-slate-700">
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('privacy_guarantee1')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('privacy_guarantee2')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('privacy_guarantee3')}</span>
              </div>
              <div className="flex items-center gap-2.5">
                <CheckCircle2 className="h-4 w-4 text-laju-600 shrink-0" />
                <span>{t('privacy_guarantee4')}</span>
              </div>
            </div>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2 rounded-full bg-laju-500 hover:bg-laju-600 px-6 py-3 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow transition-all"
              >
                <Download className="h-4 w-4 stroke-[2.5]" />
                <span>{t('privacy_cta_download')}</span>
              </Link>
              <a
                href="#rincian-kebijakan"
                className="flex items-center gap-2 rounded-full border border-slate-300 bg-white px-5 py-3 text-xs sm:text-sm font-bold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition-all shadow-xs"
              >
                <span>{t('privacy_cta_details')}</span>
              </a>
            </div>
          </div>

          {/* Right: Gorgeous Luminous Shield & Phone Artwork */}
          <div className="lg:col-span-5 flex justify-center items-center">
            <div className="relative w-full max-w-md rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white group">
              <img
                src="/images/privacy-hero.jpg"
                alt="LAJU Keamanan dan Perlindungan Privasi"
                className="w-full h-auto object-cover transform group-hover:scale-[1.02] transition-transform duration-500 ease-out"
              />
              <div className="absolute bottom-4 inset-x-4 p-3.5 rounded-2xl bg-black/50 backdrop-blur-md border border-white/10 text-white text-xs flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Lock className="h-3.5 w-3.5 text-laju-400" />
                  <span className="font-semibold text-[11px]">{t('privacy_image_badge')}</span>
                </div>
                <span className="text-[10px] font-mono text-laju-300 font-bold">256-BIT</span>
              </div>
            </div>
          </div>

        </div>

        {/* Detailed Legal & Policy Articles */}
        <div id="rincian-kebijakan" className="w-full space-y-10 text-left pt-12 border-t border-slate-200">
          
          <div className="border-b border-slate-200 pb-6">
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
              {t('privacy_articles_title')}
            </h2>
            <p className="mt-1.5 text-xs sm:text-sm text-slate-500">
              {t('privacy_articles_sub')}
            </p>
          </div>

          <div className="space-y-12">
            {/* Section 1 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
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
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
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
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Server className="h-5 w-5 text-laju-700" />
                <span>{t('privacy_sec3_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('privacy_sec3_desc')}
              </p>
            </section>

            {/* Section 4 */}
            <section className="space-y-4 pb-8 border-b border-slate-200">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <Trash2 className="h-5 w-5 text-red-600" />
                <span>{t('privacy_sec4_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('privacy_sec4_desc')}
              </p>
            </section>

            {/* Section 5 */}
            <section className="space-y-4 pb-8">
              <h3 className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2.5">
                <HelpCircle className="h-5 w-5 text-laju-700" />
                <span>{t('privacy_sec5_title')}</span>
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed max-w-4xl">
                {t('privacy_sec5_desc')}
              </p>
              <div className="flex items-center gap-3 pt-1">
                <div className="px-4 py-2.5 rounded-xl bg-white border border-slate-200 text-xs font-mono text-slate-800 font-semibold">
                  support@laju.chat
                </div>
                <a
                  href="mailto:support@laju.chat"
                  className="px-5 py-2.5 rounded-xl bg-slate-900 text-white text-xs font-bold hover:bg-slate-800 transition-colors"
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
