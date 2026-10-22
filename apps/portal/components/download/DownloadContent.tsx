'use client';

import { Download, CheckCircle, Info, Hash, Apple, Clock, ExternalLink } from 'lucide-react';
import Image from 'next/image';
import { useLanguage } from '@/context/LanguageContext';

interface DownloadContentProps {
  version: string;
  sizeText?: string | null;
  sha256?: string | null;
  releaseNotes?: string | null;
  apkDownloadUrl: string;
}

export function DownloadContent({
  version,
  sizeText,
  sha256,
  releaseNotes,
  apkDownloadUrl,
}: DownloadContentProps) {
  const { t } = useLanguage();

  const badgeText = t('download_badge').replace('{version}', version);
  const releaseNotesTitle = t('download_release_notes').replace('{version}', version);

  const handleDownloadClick = () => {
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'https://api.laju.chat';
      const cleanApiUrl = apiUrl.startsWith('http://') || apiUrl.startsWith('https://')
        ? apiUrl.replace(/\/+$/, '')
        : `https://${apiUrl.replace(/\/+$/, '')}`;
      fetch(`${cleanApiUrl}/admin/app-config/track-download`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          version,
          source: 'PORTAL_DOWNLOAD_PAGE',
          referrer: typeof document !== 'undefined' ? document.referrer : '',
        }),
      }).catch(() => {});
    } catch (_) {}
  };

  return (
    <div className="py-16 sm:py-24 bg-[#F8FAFC]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-3xl sm:text-5xl font-black text-slate-900 tracking-tight">
            {t('download_title')}
          </h1>
          <p className="mt-4 text-slate-600 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            {t('download_desc')}
          </p>
        </div>

        {/* Main Download Box */}
        <div className="rounded-3xl border border-slate-200 bg-white p-7 sm:p-10 shadow-lg relative text-left">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8">
            <div className="flex items-center gap-5">
              {/* Official App Logo Icon */}
              <div className="relative h-20 w-20 shrink-0 overflow-hidden rounded-2xl bg-slate-900 p-1.5 shadow-md border border-slate-800">
                <Image
                  src="/images/logo_icon.png"
                  alt="LAJU Logo"
                  width={80}
                  height={80}
                  className="h-full w-full object-contain"
                  priority
                />
              </div>
              <div>
                <h3 className="text-xl font-black text-slate-900">{t('download_card_title')}</h3>
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500 mt-1 font-medium">
                  <span className="font-bold text-laju-800 bg-laju-50 px-2 py-0.5 rounded border border-laju-200">
                    v{version}
                  </span>
                  <span>•</span>
                  {sizeText && (
                    <>
                      <span>{sizeText}</span>
                      <span>•</span>
                    </>
                  )}
                  <span>{t('download_android_req')}</span>
                  <span>•</span>
                  <span>{t('download_format_apk')}</span>
                </div>
              </div>
            </div>

            <a
              href={apkDownloadUrl}
              download
              onClick={handleDownloadClick}
              className="w-full md:w-auto flex items-center justify-center gap-3 rounded-full bg-laju-500 hover:bg-laju-600 px-8 py-4 text-sm font-bold text-slate-950 shadow-mint-glow hover:shadow-mint-glow-sm hover:-translate-y-0.5 transition-all active:translate-y-0 shrink-0"
            >
              <Download className="h-5 w-5 stroke-[2.5]" />
              <span>{t('download_btn')}</span>
            </a>
          </div>

          {releaseNotes && (
            <div className="mt-6 p-4 rounded-2xl bg-slate-50 border border-slate-200 text-xs text-slate-700">
              <span className="font-bold text-slate-900 block mb-1">{releaseNotesTitle}</span>
              <p className="whitespace-pre-wrap text-slate-600 leading-relaxed">{releaseNotes}</p>
            </div>
          )}

          {sha256 && (
            <div className="mt-4 p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-[11px] font-mono text-slate-600 flex items-center gap-2 overflow-hidden">
              <Hash className="h-3.5 w-3.5 text-laju-700 shrink-0" />
              <span className="text-slate-400 font-semibold shrink-0">SHA-256:</span>
              <span className="truncate select-all text-slate-800 font-bold">{sha256}</span>
            </div>
          )}

          {/* Quick Security Badges */}
          <div className="mt-8 border-t border-slate-100 pt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-600 font-semibold">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-laju-600 shrink-0" />
              <span>{t('download_badge_malware')}</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-laju-600 shrink-0" />
              <span>{t('download_badge_official')}</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-laju-600 shrink-0" />
              <span>{t('download_badge_e2ee')}</span>
            </div>
          </div>
        </div>

        {/* iOS Version Coming Soon Card */}
        <div className="mt-6 rounded-3xl border border-slate-200/90 bg-white p-6 sm:p-8 text-left shadow-xs transition-all hover:border-slate-300">
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
            <div className="flex items-center gap-4 sm:gap-5">
              <div className="flex h-14 w-14 sm:h-16 sm:w-16 shrink-0 items-center justify-center rounded-2xl bg-slate-900 text-white shadow-xs">
                <Apple className="h-7 w-7 sm:h-8 sm:w-8" />
              </div>
              <div>
                <div className="flex flex-wrap items-center gap-2.5">
                  <h3 className="text-base sm:text-lg font-black text-slate-900">
                    {t('download_ios_title')}
                  </h3>
                  <span className="inline-flex items-center gap-1 rounded-full bg-amber-50 border border-amber-200/80 px-2.5 py-0.5 text-[11px] font-bold text-amber-800">
                    <Clock className="h-3 w-3 text-amber-600" />
                    {t('download_ios_badge')}
                  </span>
                </div>
                <p className="mt-1.5 text-xs sm:text-sm text-slate-600 max-w-xl leading-relaxed">
                  {t('download_ios_desc')}
                </p>
              </div>
            </div>

            <a
              href="https://github.com/lajuapp/laju"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-slate-200 bg-slate-50 hover:bg-slate-100 hover:text-slate-950 px-5 py-2.5 text-xs font-bold text-slate-700 transition-colors shrink-0 w-full sm:w-auto"
            >
              <span>{t('download_ios_btn')}</span>
              <ExternalLink className="h-3.5 w-3.5" />
            </a>
          </div>
        </div>

        {/* Step-by-Step Installation Guide */}
        <div className="mt-16 pt-12 border-t border-slate-200 text-left">
          <h3 className="text-xl sm:text-2xl font-black text-slate-900 mb-8 flex items-center gap-2.5">
            <Info className="h-5 w-5 text-laju-600" />
            <span>{t('download_guide_title')}</span>
          </h3>

          <ol className="space-y-6 text-sm text-slate-600 leading-relaxed max-w-3xl">
            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-slate-950 text-xs font-black">
                1
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step1_title')}</strong>
                {t('download_step1_desc')}
              </div>
            </li>

            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-slate-950 text-xs font-black">
                2
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step2_title')}</strong>
                {t('download_step2_desc')}
              </div>
            </li>

            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-slate-950 text-xs font-black">
                3
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step3_title')}</strong>
                {t('download_step3_desc')}
              </div>
            </li>

            <li className="flex items-start gap-4">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-laju-500 text-slate-950 text-xs font-black">
                4
              </span>
              <div className="pt-0.5">
                <strong className="text-slate-900 font-bold block mb-0.5">{t('download_step4_title')}</strong>
                {t('download_step4_desc')}
              </div>
            </li>
          </ol>
        </div>

      </div>
    </div>
  );
}
