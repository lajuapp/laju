'use client';

import { 
  MessageSquare, 
  Clock, 
  ShieldAlert, 
  FileImage, 
  Users 
} from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

export function FeaturesSection() {
  const { t } = useLanguage();

  return (
    <section id="fitur" className="py-20 sm:py-28 bg-[#F5F4EF] border-t border-[#EAE8DE] relative overflow-hidden">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
          
          {/* Left Column: Real Dual Phones Photo on Desk */}
          <div className="lg:col-span-7 flex justify-center items-center">
            <div className="relative w-full rounded-[2.5rem] overflow-hidden shadow-2xl border border-stone-200/80 bg-white">
              <img
                src="/images/features-dual-phones.jpg"
                alt="LAJU Antarmuka Obrolan dan Pengaturan Grup"
                className="w-full h-auto object-cover transform hover:scale-[1.01] transition-transform duration-500 ease-out"
              />
            </div>
          </div>

          {/* Right Column: Feature List */}
          <div className="lg:col-span-5 space-y-8 text-left">
            <div>
              <p className="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">
                {t('features_tag')}
              </p>
              <h2 className="text-4xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
                {t('features_title_line1')}<br />
                {t('features_title_line2')}<br />
                {t('features_title_line3')}
              </h2>
            </div>

            <div className="space-y-6">
              {/* Feature 1 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5 bg-white/60">
                  <MessageSquare className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">{t('features_item1_title')}</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    {t('features_item1_desc')}
                  </p>
                </div>
              </div>

              {/* Feature 2 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5 bg-white/60">
                  <Clock className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">{t('features_item2_title')}</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    {t('features_item2_desc')}
                  </p>
                </div>
              </div>

              {/* Feature 3 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5 bg-white/60">
                  <ShieldAlert className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">{t('features_item3_title')}</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    {t('features_item3_desc')}
                  </p>
                </div>
              </div>

              {/* Feature 4 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5 bg-white/60">
                  <FileImage className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">{t('features_item4_title')}</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    {t('features_item4_desc')}
                  </p>
                </div>
              </div>

              {/* Feature 5 */}
              <div className="flex items-start gap-4">
                <div className="p-2.5 rounded-full border border-slate-300 text-slate-800 shrink-0 mt-0.5 bg-white/60">
                  <Users className="h-5 w-5 stroke-[1.5]" />
                </div>
                <div>
                  <h4 className="text-base font-bold text-slate-900">{t('features_item5_title')}</h4>
                  <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                    {t('features_item5_desc')}
                  </p>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
