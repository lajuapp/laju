'use client';

import { Download, CheckCircle, Info, Hash, ArrowLeft } from 'lucide-react';
import Link from 'next/link';
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

  return (
    <div className="py-16 sm:py-24 bg-[#F5F4EF]">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>{t('download_back')}</span>
        </Link>

        {/* Header */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-4 py-1.5 text-xs font-bold text-stone-700 mb-6 shadow-sm">
            <Download className="h-4 w-4 text-[#0D382C]" />
            <span>{badgeText}</span>
          </div>

          <h1 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight">
            {t('download_title')}
          </h1>
          <p className="mt-4 text-slate-600 text-sm sm:text-base max-w-xl mx-auto leading-relaxed">
            {t('download_desc')}
          </p>
        </div>

        {/* Main Download Box */}
        <div className="rounded-[2.5rem] border border-stone-200/80 bg-white p-8 sm:p-10 shadow-sm relative text-left">
          <div className="flex flex-col md:flex-row items-center justify-between gap-8">
            <div className="flex items-center gap-5">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-[#0D382C] text-white font-black text-2xl shadow-md">
                L
              </div>
              <div>
                <h3 className="text-xl font-extrabold text-slate-900">{t('download_card_title')}</h3>
                <div className="flex flex-wrap items-center gap-2 text-xs text-slate-500 mt-1 font-medium">
                  <span className="font-bold text-[#0D382C] bg-stone-100 px-2 py-0.5 rounded border border-stone-200">
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
              className="w-full md:w-auto flex items-center justify-center gap-3 rounded-full bg-[#0D382C] px-8 py-4 text-sm font-bold text-white shadow hover:bg-[#134E3E] hover:-translate-y-0.5 transition-all active:translate-y-0"
            >
              <Download className="h-5 w-5" />
              <span>{t('download_btn')} (v{version})</span>
            </a>
          </div>

          {releaseNotes && (
            <div className="mt-6 p-4 rounded-2xl bg-stone-50 border border-stone-200 text-xs text-slate-700">
              <span className="font-bold text-slate-900 block mb-1">{releaseNotesTitle}</span>
              <p className="whitespace-pre-wrap text-slate-600 leading-relaxed">{releaseNotes}</p>
            </div>
          )}

          {sha256 && (
            <div className="mt-4 p-3.5 rounded-xl bg-stone-50 border border-stone-200 text-[11px] font-mono text-slate-600 flex items-center gap-2 overflow-hidden">
              <Hash className="h-3.5 w-3.5 text-[#0D382C] shrink-0" />
              <span className="text-slate-400 font-semibold shrink-0">SHA-256:</span>
              <span className="truncate select-all text-slate-700 font-bold">{sha256}</span>
            </div>
          )}

          {/* Quick Security Badges */}
          <div className="mt-8 border-t border-stone-100 pt-6 grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs text-slate-600 font-semibold">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-[#0D382C] shrink-0" />
              <span>{t('download_badge_malware')}</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-[#0D382C] shrink-0" />
              <span>{t('download_badge_official')}</span>
            </div>
            <div className="flex items-center gap-2">
              <CheckCircle className="h-4 w-4 text-[#0D382C] shrink-0" />
              <span>{t('download_badge_e2ee')}</span>
            </div>
          </div>
        </div>

        {/* Step-by-Step Installation Guide */}
        <div className="mt-12 rounded-[2.5rem] border border-stone-200/80 bg-white/70 p-8 sm:p-10 text-left">
          <h3 className="text-lg font-bold text-slate-900 mb-6 flex items-center gap-2">
            <Info className="h-5 w-5 text-[#0D382C]" />
            {t('download_guide_title')}
          </h3>

          <ol className="space-y-5 text-sm text-slate-600 leading-relaxed">
            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#0D382C] text-white text-xs font-bold">
                1
              </span>
              <div>
                <strong className="text-slate-900">{t('download_step1_title')}</strong> {t('download_step1_desc')}
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#0D382C] text-white text-xs font-bold">
                2
              </span>
              <div>
                <strong className="text-slate-900">{t('download_step2_title')}</strong> {t('download_step2_desc')}
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#0D382C] text-white text-xs font-bold">
                3
              </span>
              <div>
                <strong className="text-slate-900">{t('download_step3_title')}</strong> {t('download_step3_desc')}
              </div>
            </li>

            <li className="flex items-start gap-3.5">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#0D382C] text-white text-xs font-bold">
                4
              </span>
              <div>
                <strong className="text-slate-900">{t('download_step4_title')}</strong> {t('download_step4_desc')}
              </div>
            </li>
          </ol>
        </div>
      </div>
    </div>
  );
}
