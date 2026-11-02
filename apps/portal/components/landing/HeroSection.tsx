'use client';

import Link from 'next/link';
import { Download, ChevronRight, Lock, Shield, PhoneCall, ShieldCheck, ArrowDown } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function HeroSection() {
  const { t } = useLanguage();

  const valueProps = [
    { icon: Lock, title: t('hero_prop_privacy'), detail: t('hero_prop_privacy_sub') },
    { icon: Shield, title: t('hero_prop_lightweight'), detail: t('hero_prop_lightweight_sub') },
    { icon: PhoneCall, title: t('hero_prop_groups'), detail: t('hero_prop_groups_sub') },
    { icon: ShieldCheck, title: t('hero_prop_crossdevice'), detail: t('hero_prop_crossdevice_sub') },
  ];

  return (
    <section className="hero-stage relative isolate flex min-h-[calc(100svh-5rem)] overflow-hidden bg-[#F5F4EF]">
      <div className="hero-art absolute inset-0" aria-hidden="true">
        <img
          src="/images/hero-phone.jpg"
          alt=""
          className="hero-art-image h-full w-full object-cover object-[66%_center] lg:object-center"
        />
        <div className="hero-art-wash absolute inset-0" />
        <div className="hero-art-grain absolute inset-0" />
      </div>

      <div className="relative z-10 mx-auto flex w-full max-w-7xl flex-1 flex-col justify-center px-5 pb-7 pt-10 sm:px-8 sm:pb-9 lg:px-8 lg:py-10">
        <div className="grid flex-1 grid-cols-1 items-center gap-8 lg:grid-cols-12">
          <div className="hero-copy max-w-2xl text-left lg:col-span-7 lg:max-w-[620px] xl:col-span-6">
            <h1 className="hero-enter hero-enter-1 text-[2.65rem] font-black leading-[0.99] tracking-[-0.055em] text-slate-950 sm:text-5xl lg:text-[3.8rem] xl:text-[4.6rem]">
              {t('hero_title_part1')}
              <br />
              <span className="hero-title-accent">{t('hero_title_part2')}</span>
            </h1>

            <p className="hero-enter hero-enter-2 mt-5 max-w-xl text-sm leading-7 text-slate-700 sm:mt-6 sm:text-lg sm:leading-8">
              {t('hero_subtitle')}
            </p>

            <div className="hero-enter hero-enter-3 mt-6 flex flex-wrap items-center gap-3 sm:mt-8 sm:gap-4">
              <Link
                href="/download"
                className="group inline-flex min-h-12 items-center gap-2.5 rounded-full bg-[#0D382C] px-6 py-3 text-sm font-bold text-white shadow-[0_12px_28px_-10px_rgba(13,56,44,0.55)] transition-all duration-300 hover:-translate-y-0.5 hover:bg-[#134E3E] hover:shadow-[0_16px_32px_-10px_rgba(13,56,44,0.48)] active:translate-y-0 sm:px-7 sm:py-3.5"
              >
                <Download className="h-4 w-4 transition-transform duration-300 group-hover:translate-y-0.5" />
                <span>{t('hero_cta_android')}</span>
              </Link>
              <a
                href="#fitur"
                className="group inline-flex min-h-12 items-center gap-2 rounded-full px-4 py-3 text-sm font-bold text-slate-800 transition-colors hover:text-[#0D382C] sm:px-5"
              >
                <span>{t('hero_cta_learn')}</span>
                <ChevronRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
              </a>
            </div>

            <div className="hero-enter hero-enter-4 mt-7 grid grid-cols-2 gap-x-4 gap-y-3 rounded-2xl border border-[#0D382C]/10 bg-[#F5F4EF]/75 p-3 pt-4 shadow-sm backdrop-blur-md sm:mt-9 sm:grid-cols-4 sm:gap-5 sm:rounded-none sm:border-x-0 sm:border-b-0 sm:bg-transparent sm:p-0 sm:pt-6 sm:shadow-none sm:backdrop-blur-none">
              {valueProps.map(({ icon: Icon, title, detail }) => (
                <div key={title} className="flex min-w-0 items-start gap-2.5 sm:block sm:space-y-2">
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-white/75 text-[#0D382C] shadow-sm ring-1 ring-[#0D382C]/10 backdrop-blur-sm sm:h-9 sm:w-9">
                    <Icon className="h-4 w-4" />
                  </div>
                  <div className="min-w-0 sm:pt-0.5">
                    <div className="text-[11px] font-extrabold leading-snug text-slate-900 sm:text-xs">{title}</div>
                    <div className="mt-0.5 text-[10px] leading-snug text-slate-600 sm:text-[11px]">{detail}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="hidden lg:col-span-5 lg:block xl:col-span-6" aria-hidden="true" />
        </div>

        <a href="#fitur" className="hero-scroll-cue mx-auto mt-3 hidden items-center gap-2 text-[10px] font-bold uppercase tracking-[0.2em] text-[#0D382C]/70 transition-colors hover:text-[#0D382C] sm:inline-flex lg:mt-0">
          <span>{t('nav_features')}</span>
          <ArrowDown className="h-3.5 w-3.5" />
        </a>
      </div>
    </section>
  );
}
