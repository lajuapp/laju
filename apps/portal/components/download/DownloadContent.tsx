'use client';

import { CheckCircle, ShieldCheck, Apple, ExternalLink, Sparkles } from 'lucide-react';
import Image from 'next/image';
import { useLanguage } from '@/context/LanguageContext';

interface DownloadContentProps {
  androidVersion: string;
  iosVersion: string;
  playStoreUrl: string;
  appStoreUrl: string;
  releaseNotes?: string | null;
}

export function DownloadContent({
  androidVersion,
  iosVersion,
  playStoreUrl,
  appStoreUrl,
  releaseNotes,
}: DownloadContentProps) {
  const { t } = useLanguage();

  const releaseNotesTitle = t('download_release_notes').replace('{version}', androidVersion);

  return (
    <div className="py-16 sm:py-24 bg-[#F5F4EF]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-laju-500/10 border border-laju-500/20 text-laju-800 text-xs font-bold mb-4">
            <Sparkles className="w-3.5 h-3.5 text-laju-600" />
            <span>{t('download_badge_official_store')}</span>
          </div>
          <h1 className="text-3xl sm:text-5xl font-black text-slate-900 tracking-tight">
            {t('download_title')}
          </h1>
          <p className="mt-4 text-slate-600 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            {t('download_desc')}
          </p>
        </div>

        {/* Store Download Cards (Google Play & Apple App Store) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Card 1: Google Play Store */}
          <div className="rounded-3xl border border-[#EAE8DE] bg-white p-7 sm:p-8 shadow-lg text-left flex flex-col justify-between hover:border-slate-300 transition-all">
            <div>
              <div className="flex items-center justify-between mb-5">
                <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-2xl bg-slate-900 p-2 shadow-md border border-slate-800">
                  <Image
                    src="/images/logo_icon.png"
                    alt="LAJU Logo"
                    width={56}
                    height={56}
                    className="h-full w-full object-contain"
                  />
                </div>
                <span className="font-bold text-xs text-laju-800 bg-laju-50 px-2.5 py-1 rounded-full border border-laju-200">
                  v{androidVersion}
                </span>
              </div>

              <h3 className="text-xl font-black text-slate-900">{t('download_card_android_title')}</h3>
              <p className="text-xs text-slate-500 mt-1.5 font-medium">
                {t('download_android_req')}
              </p>
              <p className="text-sm text-slate-600 mt-3 leading-relaxed">
                {t('download_android_desc')}
              </p>
            </div>

            <div className="mt-8 pt-6 border-t border-[#EAE8DE]/70">
              <a
                href={playStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-3 rounded-2xl bg-slate-950 hover:bg-slate-900 px-6 py-4 text-sm font-bold text-white shadow-md hover:-translate-y-0.5 transition-all active:translate-y-0"
              >
                {/* Google Play Triangle SVG */}
                <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none">
                  <path d="M4.5 3.5L15 12L4.5 20.5V3.5Z" fill="#00D2FF" />
                  <path d="M15 12L18.5 8.5L4.5 3.5L15 12Z" fill="#00F076" />
                  <path d="M4.5 20.5L18.5 15.5L15 12L4.5 20.5Z" fill="#FF3A44" />
                  <path d="M18.5 8.5L21.5 10.5C22.3 11 22.3 12.2 21.5 12.7L18.5 14.7L15.8 12L18.5 8.5Z" fill="#FFA500" />
                </svg>
                <span>{t('download_playstore_btn')}</span>
                <ExternalLink className="h-4 w-4 ml-auto text-slate-400" />
              </a>
            </div>
          </div>

          {/* Card 2: Apple App Store */}
          <div className="rounded-3xl border border-[#EAE8DE] bg-white p-7 sm:p-8 shadow-lg text-left flex flex-col justify-between hover:border-slate-300 transition-all">
            <div>
              <div className="flex items-center justify-between mb-5">
                <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-slate-900 text-white shadow-md border border-slate-800">
                  <Apple className="h-7 w-7 text-white" />
                </div>
                <span className="font-bold text-xs text-laju-800 bg-laju-50 px-2.5 py-1 rounded-full border border-laju-200">
                  v{iosVersion}
                </span>
              </div>

              <h3 className="text-xl font-black text-slate-900">{t('download_card_ios_title')}</h3>
              <p className="text-xs text-slate-500 mt-1.5 font-medium">
                {t('download_ios_req')}
              </p>
              <p className="text-sm text-slate-600 mt-3 leading-relaxed">
                {t('download_ios_desc')}
              </p>
            </div>

            <div className="mt-8 pt-6 border-t border-[#EAE8DE]/70">
              <a
                href={appStoreUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-3 rounded-2xl bg-slate-950 hover:bg-slate-900 px-6 py-4 text-sm font-bold text-white shadow-md hover:-translate-y-0.5 transition-all active:translate-y-0"
              >
                <Apple className="h-5 w-5 text-white" />
                <span>{t('download_appstore_btn')}</span>
                <ExternalLink className="h-4 w-4 ml-auto text-slate-400" />
              </a>
            </div>
          </div>
        </div>

        {/* Release Notes (if present from admin config) */}
        {releaseNotes && (
          <div className="mt-8 p-6 rounded-3xl bg-white border border-[#EAE8DE] text-left shadow-xs">
            <span className="font-bold text-slate-900 text-sm block mb-1.5">{releaseNotesTitle}</span>
            <p className="whitespace-pre-wrap text-slate-600 text-xs sm:text-sm leading-relaxed">{releaseNotes}</p>
          </div>
        )}

        {/* Quick Security Badges */}
        <div className="mt-8 p-6 rounded-3xl bg-white border border-[#EAE8DE] grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-600 font-semibold shadow-xs">
          <div className="flex items-center gap-2.5">
            <CheckCircle className="h-4 w-4 text-laju-600 shrink-0" />
            <span>{t('download_badge_official_store')}</span>
          </div>
          <div className="flex items-center gap-2.5">
            <CheckCircle className="h-4 w-4 text-laju-600 shrink-0" />
            <span>{t('download_badge_auto_update')}</span>
          </div>
          <div className="flex items-center gap-2.5">
            <ShieldCheck className="h-4 w-4 text-laju-600 shrink-0" />
            <span>{t('download_badge_e2ee')}</span>
          </div>
        </div>

        {/* Step-by-Step Official Getting Started Guide */}
        <div className="mt-16 pt-12 border-t border-[#EAE8DE] text-left">
          <h3 className="text-xl sm:text-2xl font-black text-slate-900 mb-8 flex items-center gap-2.5">
            <Sparkles className="h-5 w-5 text-laju-600" />
            <span>{t('download_guide_title')}</span>
          </h3>

          <ol className="space-y-6 text-sm text-slate-600 leading-relaxed max-w-3xl">
            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-white text-xs font-black">
                1
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step1_title')}</strong>
                {t('download_step1_desc')}
              </div>
            </li>

            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-white text-xs font-black">
                2
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step2_title')}</strong>
                {t('download_step2_desc')}
              </div>
            </li>

            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-white text-xs font-black">
                3
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step3_title')}</strong>
                {t('download_step3_desc')}
              </div>
            </li>
          </ol>
        </div>

      </div>
    </div>
  );
}
