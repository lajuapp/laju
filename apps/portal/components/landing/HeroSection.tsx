'use client';

import Link from 'next/link';
import { 
  Download, 
  ChevronRight, 
  Lock, 
  Shield, 
  PhoneCall, 
  ShieldCheck 
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function HeroSection() {
  const { t } = useLanguage();

  return (
    <section className="relative overflow-hidden bg-[#F8FAFC] pt-8 pb-16 md:pt-14 md:pb-24">
      {/* Background Photography for Large Screens */}
      <div className="absolute inset-0 pointer-events-none hidden lg:block overflow-hidden">
        <div className="absolute right-0 top-0 bottom-0 w-7/12 xl:w-1/2 h-full">
          <img
            src="/images/hero-phone.jpg"
            alt="LAJU Messenger"
            className="w-full h-full object-cover object-[72%_center]"
          />
          {/* Seamless gradient blend on the left edge into the #F8FAFC background */}
          <div className="absolute inset-y-0 left-0 w-48 bg-gradient-to-r from-[#F8FAFC] via-[#F8FAFC]/85 to-transparent" />
          {/* Subtle top blend towards navbar */}
          <div className="absolute top-0 inset-x-0 h-16 bg-gradient-to-b from-[#F8FAFC]/60 to-transparent" />
        </div>
      </div>

      <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
          
          {/* Left Column: Copy & Actions (No chip badge) */}
          <div className="lg:col-span-7 xl:col-span-6 space-y-6 text-left z-10 py-4 lg:py-8">
            {/* Title */}
            <h1 className="text-4xl sm:text-5xl md:text-6xl font-black tracking-tight text-slate-900 leading-[1.1]">
              {t('hero_title_part1')}<br />
              <span className="text-laju-700">{t('hero_title_part2')}</span>
            </h1>

            {/* Subtitle */}
            <p className="text-slate-600 text-base sm:text-lg max-w-xl leading-relaxed font-normal">
              {t('hero_subtitle')}
            </p>

            {/* Buttons */}
            <div className="pt-2 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2.5 rounded-full bg-laju-500 hover:bg-laju-600 px-7 py-3.5 text-sm font-bold text-slate-950 shadow-mint-glow hover:shadow-mint-glow-sm transition-all active:scale-95"
              >
                <Download className="h-4 w-4 stroke-[2.5]" />
                <span>{t('hero_cta_android')}</span>
              </Link>

              <a
                href="#fitur"
                className="flex items-center gap-2 px-5 py-3.5 text-sm font-bold text-slate-700 hover:text-slate-950 transition-colors"
              >
                <span>{t('hero_cta_learn')}</span>
                <ChevronRight className="h-4 w-4" />
              </a>
            </div>

            {/* 4 Value Props (Horizontal) */}
            <div className="pt-8 sm:pt-10 grid grid-cols-2 sm:grid-cols-4 gap-6 text-xs text-slate-700">
              <div className="space-y-1.5">
                <div className="h-8 w-8 rounded-lg bg-emerald-100/60 flex items-center justify-center text-emerald-700">
                  <Lock className="h-4 w-4" />
                </div>
                <div className="font-bold text-slate-900 leading-snug">
                  {t('hero_prop_privacy')}
                </div>
                <div className="text-[11px] text-slate-500 font-medium">{t('hero_prop_privacy_sub')}</div>
              </div>

              <div className="space-y-1.5">
                <div className="h-8 w-8 rounded-lg bg-teal-100/60 flex items-center justify-center text-teal-700">
                  <Shield className="h-4 w-4" />
                </div>
                <div className="font-bold text-slate-900 leading-snug">
                  {t('hero_prop_lightweight')}
                </div>
                <div className="text-[11px] text-slate-500 font-medium">{t('hero_prop_lightweight_sub')}</div>
              </div>

              <div className="space-y-1.5">
                <div className="h-8 w-8 rounded-lg bg-cyan-100/60 flex items-center justify-center text-cyan-700">
                  <PhoneCall className="h-4 w-4" />
                </div>
                <div className="font-bold text-slate-900 leading-snug">
                  {t('hero_prop_groups')}
                </div>
                <div className="text-[11px] text-slate-500 font-medium">{t('hero_prop_groups_sub')}</div>
              </div>

              <div className="space-y-1.5">
                <div className="h-8 w-8 rounded-lg bg-emerald-100/60 flex items-center justify-center text-emerald-700">
                  <ShieldCheck className="h-4 w-4" />
                </div>
                <div className="font-bold text-slate-900 leading-snug">
                  {t('hero_prop_crossdevice')}
                </div>
                <div className="text-[11px] text-slate-500 font-medium">{t('hero_prop_crossdevice_sub')}</div>
              </div>
            </div>
          </div>

          {/* Photo visible on mobile & tablet */}
          <div className="lg:hidden flex justify-center items-center">
            <div className="relative w-full rounded-3xl overflow-hidden shadow-xl border border-slate-200">
              <img
                src="/images/hero-phone.jpg"
                alt="LAJU Messenger"
                className="w-full h-auto object-cover"
              />
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
