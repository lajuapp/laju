'use client';

import Link from 'next/link';
import { Smartphone, ChevronRight } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';
import { Reveal } from './Reveal';

export function DownloadCTA() {
  const { t } = useLanguage();

  return (
    <section className="relative isolate overflow-hidden bg-[#0D382C] py-16 text-white sm:py-20 lg:py-24">
      <div aria-hidden="true" className="pointer-events-none absolute -right-36 -top-44 h-[32rem] w-[32rem] rounded-full bg-[#6F987F]/20 blur-3xl" />
      <div aria-hidden="true" className="pointer-events-none absolute -bottom-56 left-[18%] h-[28rem] w-[28rem] rounded-full bg-[#B9DCC8]/[0.08] blur-3xl" />

      <div className="relative mx-auto max-w-7xl px-5 sm:px-8 lg:px-8">
        <div className="grid grid-cols-1 items-center gap-10 lg:grid-cols-12 lg:gap-12">
          <Reveal direction="left" className="space-y-5 text-left sm:space-y-6 lg:col-span-6">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.2em] text-[#B9DCC8] sm:text-xs">
              {t('cta_tag')}
            </p>
            <h2 className="text-3xl font-black leading-[1.08] tracking-tight text-white sm:text-4xl lg:text-5xl">
              {t('cta_title_line1')}<br />
              <span className="text-[#B9DCC8]">{t('cta_title_line2')}</span>
            </h2>
            <p className="max-w-lg text-sm leading-relaxed text-white/75 sm:text-base sm:leading-7">
              {t('cta_subtitle_line1')} {t('cta_subtitle_line2')}
            </p>

            <div className="flex flex-wrap items-center gap-3 pt-1 sm:gap-4">
              <Link
                href="/download"
                className="group inline-flex min-h-12 items-center gap-2.5 rounded-full bg-[#F5F4EF] px-6 py-3 text-sm font-bold text-[#0D382C] shadow-[0_12px_30px_-12px_rgba(0,0,0,0.55)] transition-all duration-300 hover:-translate-y-0.5 hover:bg-white sm:px-7"
              >
                <Smartphone className="h-4 w-4 stroke-[2.5]" />
                <span>{t('cta_download_btn')}</span>
              </Link>
              <a
                href="#fitur"
                className="group inline-flex min-h-12 items-center gap-2 rounded-full border border-white/25 px-5 py-3 text-sm font-bold text-white/90 transition-all hover:border-white/60 hover:bg-white/10 hover:text-white"
              >
                <span>{t('cta_monitor_btn')}</span>
                <ChevronRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
              </a>
            </div>
          </Reveal>

          <Reveal direction="right" delay={130} className="lg:col-span-6">
            <div className="landing-image-frame group relative aspect-[16/10] overflow-hidden rounded-[1.75rem] border border-white/15 bg-white/5 shadow-[0_32px_80px_-38px_rgba(0,0,0,0.7)] sm:rounded-[2rem]">
              <img
                src="/images/cta-devices.jpg"
                alt="LAJU di Berbagai Perangkat"
                className="h-full w-full object-cover transition-transform duration-700 ease-out group-hover:scale-[1.025]"
              />
              <div className="pointer-events-none absolute inset-0 ring-1 ring-inset ring-white/10" />
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}
