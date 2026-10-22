'use client';

import { 
  MessageSquare,
  Lock, 
  PhoneCall, 
  Clock, 
  Radio, 
  ShieldCheck,
  Smartphone,
  EyeOff
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function FeaturesSection() {
  const { t } = useLanguage();

  const featureItems = [
    {
      icon: MessageSquare,
      title: t('features_item1_title'),
      desc: t('features_item1_desc'),
    },
    {
      icon: PhoneCall,
      title: t('features_item2_title'),
      desc: t('features_item2_desc'),
    },
    {
      icon: Clock,
      title: t('features_item3_title'),
      desc: t('features_item3_desc'),
    },
    {
      icon: Radio,
      title: t('features_item4_title'),
      desc: t('features_item4_desc'),
    },
    {
      icon: ShieldCheck,
      title: t('features_item5_title'),
      desc: t('features_item5_desc'),
    },
    {
      icon: EyeOff,
      title: t('features_item6_title'),
      desc: t('features_item6_desc'),
    },
  ];

  return (
    <section id="fitur" className="py-20 sm:py-28 bg-white border-t border-slate-200 relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-14 items-center">
          
          {/* Left Column: Real Dual Phones Photo on Desk */}
          <div className="lg:col-span-6 flex justify-center items-center">
            <div className="relative w-full rounded-[2.5rem] overflow-hidden shadow-2xl border border-slate-200/90 bg-white">
              <img
                src="/images/features-dual-phones.jpg"
                alt="LAJU Antarmuka Obrolan dan Pengaturan Privasi"
                className="w-full h-auto object-cover transform hover:scale-[1.01] transition-transform duration-500 ease-out"
              />
            </div>
          </div>

          {/* Right Column: Title, Subtitle, & 2x3 Feature Cards Grid */}
          <div className="lg:col-span-6 space-y-6 text-left">
            <div>
              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black text-slate-900 tracking-tight leading-[1.15]">
                {t('features_title_line1')}<br />
                <span className="text-laju-700">{t('features_title_line2')}</span>{' '}
                {t('features_title_line3')}
              </h2>
              <p className="mt-3 text-slate-600 text-sm sm:text-base leading-relaxed font-normal">
                {t('features_subtitle')}
              </p>
            </div>

            {/* 6 Clean Feature Points in 2 Columns (No boxed cards) */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-7 pt-4">
              {featureItems.map((item, idx) => {
                const Icon = item.icon;
                return (
                  <div key={idx} className="space-y-1.5 text-left">
                    <div className="flex items-center gap-3">
                      <div className="h-8 w-8 rounded-xl bg-laju-50 flex items-center justify-center text-laju-700 shrink-0">
                        <Icon className="h-4 w-4 stroke-[2.2]" />
                      </div>
                      <h4 className="text-sm sm:text-base font-bold text-slate-900">
                        {item.title}
                      </h4>
                    </div>
                    <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-normal pl-11">
                      {item.desc}
                    </p>
                  </div>
                );
              })}
            </div>

          </div>

        </div>
      </div>
    </section>
  );
}
