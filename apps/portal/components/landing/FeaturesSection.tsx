'use client';

import {
  MessageSquare,
  PhoneCall,
  Clock,
  Radio,
  ShieldCheck,
  EyeOff,
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';
import { Reveal } from './Reveal';

export function FeaturesSection() {
  const { t } = useLanguage();

  const featureItems = [
    { icon: MessageSquare, title: t('features_item1_title'), desc: t('features_item1_desc') },
    { icon: PhoneCall, title: t('features_item2_title'), desc: t('features_item2_desc') },
    { icon: Clock, title: t('features_item3_title'), desc: t('features_item3_desc') },
    { icon: Radio, title: t('features_item4_title'), desc: t('features_item4_desc') },
    { icon: ShieldCheck, title: t('features_item5_title'), desc: t('features_item5_desc') },
    { icon: EyeOff, title: t('features_item6_title'), desc: t('features_item6_desc') },
  ];

  return (
    <section id="fitur" className="relative overflow-hidden border-t border-[#EAE8DE] bg-[#F5F4EF] py-16 sm:py-20 lg:py-24">
      <div className="mx-auto max-w-7xl px-5 sm:px-8 lg:px-8">
        <Reveal className="mb-9 max-w-4xl space-y-3 text-left sm:mb-12 sm:space-y-4">
          <p className="text-[10px] font-extrabold uppercase tracking-[0.2em] text-[#0D382C] sm:text-xs">
            {t('features_tag')}
          </p>
          <h2 className="text-3xl font-black leading-[1.08] tracking-tight text-slate-900 sm:text-4xl lg:text-5xl">
            {t('features_title_line1')}<br />
            <span className="text-[#0D382C]">{t('features_title_line2')}</span>{' '}
            {t('features_title_line3')}
          </h2>
          <p className="max-w-3xl text-sm leading-relaxed text-slate-600 sm:text-base sm:leading-7">
            {t('features_subtitle')}
          </p>
        </Reveal>

        <div className="grid grid-cols-1 items-start gap-8 lg:grid-cols-12 lg:gap-12">
          <Reveal direction="left" className="lg:col-span-5">
            <div className="landing-image-frame group relative aspect-[16/11] overflow-hidden rounded-[1.75rem] border border-stone-200/80 bg-white shadow-[0_22px_55px_-35px_rgba(15,23,42,0.45)] sm:rounded-[2rem] lg:aspect-[5/4]">
              <img
                src="/images/features-dual-phones.jpg"
                alt="LAJU Antarmuka Obrolan dan Pengaturan Privasi"
                className="h-full w-full object-cover transition-transform duration-700 ease-out group-hover:scale-[1.025]"
              />
              <div className="pointer-events-none absolute inset-x-0 bottom-0 h-20 bg-gradient-to-t from-slate-950/15 to-transparent" />
            </div>
          </Reveal>

          <div className="grid grid-cols-1 gap-x-7 sm:grid-cols-2 lg:col-span-7 lg:gap-x-9">
            {featureItems.map(({ icon: Icon, title, desc }, idx) => (
              <Reveal key={title} delay={idx * 65} className="border-t border-[#E1DED3] py-5 sm:py-6">
                <div className="flex items-start gap-3.5">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white text-[#0D382C] shadow-sm ring-1 ring-[#0D382C]/[0.07]">
                    <Icon className="h-4 w-4 stroke-[2.1]" />
                  </div>
                  <div className="min-w-0 pt-0.5">
                    <h3 className="text-sm font-bold leading-snug text-slate-900 sm:text-[15px]">
                      {title}
                    </h3>
                    <p className="mt-1.5 text-xs leading-relaxed text-slate-600 sm:text-sm">
                      {desc}
                    </p>
                  </div>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
