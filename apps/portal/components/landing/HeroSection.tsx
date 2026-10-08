'use client';

import Link from 'next/link';
import { 
  Download, 
  PlayCircle, 
  Lock, 
  Zap, 
  Users, 
  Laptop 
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function HeroSection() {
  const { t } = useLanguage();

  return (
    <section className="relative overflow-hidden bg-[#F5F4EF] pt-6 pb-16 md:pt-10 md:pb-20">
      {/* Background Lifestyle Photography for Large Screens */}
      <div className="absolute inset-0 pointer-events-none hidden lg:block overflow-hidden">
        <div className="absolute right-0 top-0 bottom-0 w-7/12 xl:w-1/2 h-full">
          <img
            src="/images/hero-phone.jpg"
            alt="LAJU Messenger"
            className="w-full h-full object-cover object-[72%_center]"
          />
          {/* Seamless gradient blend on the left edge into the #F5F4EF background */}
          <div className="absolute inset-y-0 left-0 w-48 bg-gradient-to-r from-[#F5F4EF] via-[#F5F4EF]/85 to-transparent" />
          {/* Subtle top blend towards navbar */}
          <div className="absolute top-0 inset-x-0 h-16 bg-gradient-to-b from-[#F5F4EF]/60 to-transparent" />
        </div>
      </div>

      <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">
          
          {/* Left Column: Copy & Actions */}
          <div className="lg:col-span-6 xl:col-span-6 space-y-6 text-left z-10 py-4 lg:py-10">
            {/* Tag */}
            <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">
              {t('hero_tag')}
            </p>

            {/* Title */}
            <h1 className="text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-slate-900 leading-[1.05]">
              {t('hero_title_part1')}<br />
              {t('hero_title_part2')}
            </h1>

            {/* Subtitle */}
            <p className="text-slate-600 text-base sm:text-lg max-w-md leading-relaxed font-normal">
              {t('hero_subtitle')}
            </p>

            {/* Buttons */}
            <div className="pt-2 flex flex-wrap items-center gap-4">
              <Link
                href="/download"
                className="flex items-center gap-2.5 rounded-full bg-[#0D382C] px-7 py-3.5 text-sm font-semibold text-white shadow-sm hover:bg-[#134E3E] transition-all active:scale-95"
              >
                <Download className="h-4 w-4" />
                <span>{t('hero_cta_android')}</span>
              </Link>

              <a
                href="#fitur"
                className="flex items-center gap-2 px-4 py-3.5 text-sm font-semibold text-slate-800 hover:text-slate-950 transition-colors"
              >
                <PlayCircle className="h-5 w-5 text-slate-700" />
                <span>{t('hero_cta_learn')}</span>
              </a>
            </div>

            {/* 4 Value Props (Horizontal) */}
            <div className="pt-8 sm:pt-12 grid grid-cols-2 sm:grid-cols-4 gap-6 text-xs text-slate-700">
              <div className="space-y-2">
                <Lock className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  {t('hero_prop_privacy')}<br />
                  <span className="font-normal text-slate-600">{t('hero_prop_privacy_sub')}</span>
                </div>
              </div>

              <div className="space-y-2">
                <Zap className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  {t('hero_prop_lightweight')}<br />
                  <span className="font-normal text-slate-600">{t('hero_prop_lightweight_sub')}</span>
                </div>
              </div>

              <div className="space-y-2">
                <Users className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  {t('hero_prop_groups')}<br />
                  <span className="font-normal text-slate-600">{t('hero_prop_groups_sub')}</span>
                </div>
              </div>

              <div className="space-y-2">
                <Laptop className="h-5 w-5 text-slate-800 stroke-[1.5]" />
                <div className="font-semibold text-slate-900 leading-snug">
                  {t('hero_prop_crossdevice')}<br />
                  <span className="font-normal text-slate-600">{t('hero_prop_crossdevice_sub')}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column for Mobile/Tablet: Clean Framed Photo */}
          <div className="block lg:hidden mt-2">
            <div className="rounded-[2.5rem] overflow-hidden shadow-xl border border-stone-200/90 bg-white">
              <img
                src="/images/hero-phone.jpg"
                alt="LAJU Messenger App"
                className="w-full h-auto object-cover"
              />
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
