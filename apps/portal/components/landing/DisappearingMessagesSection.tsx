'use client';

import { useLanguage } from '@/context/LanguageContext';
import { Reveal } from './Reveal';

export function DisappearingMessagesSection() {
  const { t } = useLanguage();

  return (
    <section className="bg-[#F5F4EF] px-4 py-14 sm:px-6 sm:py-20 lg:px-8 lg:py-24">
      <Reveal className="relative mx-auto min-h-[540px] max-w-7xl overflow-hidden rounded-[2rem] border border-white/50 bg-slate-950 shadow-[0_30px_80px_-42px_rgba(15,23,42,0.5)] sm:min-h-[580px] sm:rounded-[2.5rem] lg:min-h-[600px]">
        <img
          src="/images/disappearing-lake.jpg"
          alt="Ruang percakapan LAJU dengan pesan sementara di tepi danau senja"
          className="absolute inset-0 h-full w-full object-cover object-[68%_center]"
        />
        <div className="disappear-image-wash absolute inset-0" />

        <div className="relative z-10 mx-auto flex min-h-[540px] max-w-7xl items-end px-6 pb-9 pt-16 sm:min-h-[580px] sm:px-10 sm:pb-12 lg:min-h-[600px] lg:items-center lg:px-14 lg:py-16">
          <div className="max-w-xl space-y-4 text-left sm:space-y-5">
            <p className="text-[10px] font-extrabold uppercase tracking-[0.2em] text-[#D3E8D9] sm:text-xs">
              {t('disappear_tag')}
            </p>
            <h2 className="text-3xl font-black leading-[1.08] tracking-tight text-white sm:text-4xl lg:text-5xl">
              {t('disappear_title_line1')}<br />
              <span className="text-[#B9DCC8]">{t('disappear_title_line2')}</span>
            </h2>
            <p className="max-w-lg text-sm leading-relaxed text-white/80 sm:text-base sm:leading-7">
              {t('disappear_desc')}
            </p>
          </div>
        </div>
      </Reveal>
    </section>
  );
}
