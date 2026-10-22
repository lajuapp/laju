'use client';

import Link from 'next/link';
import { Lock, EyeOff, ShieldAlert, Trash2, ChevronRight } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function SecuritySection() {
  const { t } = useLanguage();

  return (
    <section id="privasi" className="py-20 sm:py-28 bg-[#0B1015] text-white relative overflow-hidden border-t border-slate-800">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Copy & Link (No chip badge) */}
          <div className="lg:col-span-5 space-y-6 text-left">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-black text-white tracking-tight leading-[1.1]">
              {t('sec_title_line1')}<br />
              <span className="text-laju-400">{t('sec_title_line2')}</span>
            </h2>

            <p className="text-slate-300 text-base sm:text-lg leading-relaxed font-normal">
              {t('sec_desc')}
            </p>

            <div className="pt-2">
              <Link
                href="/privacy"
                className="inline-flex items-center gap-2 rounded-full bg-laju-500 hover:bg-laju-600 px-6 py-3.5 text-xs sm:text-sm font-bold text-slate-950 shadow-mint-glow transition-all active:scale-95"
              >
                <span>{t('sec_cta')}</span>
                <ChevronRight className="h-4 w-4 stroke-[2.5]" />
              </Link>
            </div>
          </div>

          {/* Right Column: Real Notebook Photo + 4 Dark Cards */}
          <div className="lg:col-span-7 relative">
            <div className="rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-700/80 relative min-h-[460px] sm:min-h-[500px] flex items-center justify-end p-5 sm:p-8">
              {/* Background Notebook Photo */}
              <img
                src="/images/security-notebook.jpg"
                alt="LAJU Notebook Keamanan dan Privasi"
                className="absolute inset-0 w-full h-full object-cover object-center"
              />

              {/* Gradient overlay to ensure cards are readable against the photo */}
              <div className="absolute inset-0 bg-gradient-to-r from-slate-950/30 via-slate-950/70 to-slate-950/90 pointer-events-none" />

              {/* 4 Sleek Dark Cards */}
              <div className="relative z-10 w-full max-w-xs sm:max-w-sm space-y-3">
                {/* Card 1 */}
                <div className="p-4 rounded-2xl bg-[#131B22]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#131B22] transition-colors">
                  <div className="p-2.5 rounded-xl bg-laju-500/15 text-laju-400 shrink-0">
                    <Lock className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">{t('sec_card1_title')}</div>
                    <div className="text-xs text-slate-300">{t('sec_card1_sub')}</div>
                  </div>
                </div>

                {/* Card 2 */}
                <div className="p-4 rounded-2xl bg-[#131B22]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#131B22] transition-colors">
                  <div className="p-2.5 rounded-xl bg-laju-500/15 text-laju-400 shrink-0">
                    <EyeOff className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">{t('sec_card2_title')}</div>
                    <div className="text-xs text-slate-300">{t('sec_card2_sub')}</div>
                  </div>
                </div>

                {/* Card 3 */}
                <div className="p-4 rounded-2xl bg-[#131B22]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#131B22] transition-colors">
                  <div className="p-2.5 rounded-xl bg-laju-500/15 text-laju-400 shrink-0">
                    <ShieldAlert className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">{t('sec_card3_title')}</div>
                    <div className="text-xs text-slate-300">{t('sec_card3_sub')}</div>
                  </div>
                </div>

                {/* Card 4 */}
                <div className="p-4 rounded-2xl bg-[#131B22]/90 backdrop-blur-md border border-white/10 flex items-center gap-3.5 text-left shadow-lg hover:bg-[#131B22] transition-colors">
                  <div className="p-2.5 rounded-xl bg-red-500/15 text-red-400 shrink-0">
                    <Trash2 className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="font-bold text-white text-sm">{t('sec_card4_title')}</div>
                    <div className="text-xs text-slate-300">{t('sec_card4_sub')}</div>
                  </div>
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
