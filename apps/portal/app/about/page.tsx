'use client';

import { 
  ArrowLeft, 
  ExternalLink, 
  CheckCircle2, 
  Globe, 
  Building2, 
  ShieldCheck, 
  Code2, 
  Sparkles,
  GitBranch,
  Layers,
  Server
} from 'lucide-react';
import Link from 'next/link';
import { useLanguage } from '@/context/LanguageContext';

export default function AboutPage() {
  const { t } = useLanguage();

  return (
    <div className="py-12 sm:py-20 bg-[#F5F4EF] min-h-screen">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        
        {/* Back Link */}
        <Link
          href="/"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 hover:text-slate-900 mb-8 transition-colors"
        >
          <ArrowLeft className="h-4 w-4" />
          <span>{t('about_back')}</span>
        </Link>

        {/* Hero Section */}
        <div className="max-w-3xl mb-14 text-left">
          <div className="inline-flex items-center gap-2 rounded-full border border-stone-200 bg-white px-4 py-1.5 text-xs font-bold text-stone-700 shadow-sm mb-6">
            <Sparkles className="h-4 w-4 text-[#0D382C]" />
            <span>{t('about_badge')}</span>
          </div>

          <h1 className="text-4xl sm:text-5xl font-black text-slate-900 tracking-tight leading-[1.1] mb-6">
            {t('about_hero_title')}
          </h1>

          <p className="text-slate-600 text-base sm:text-lg leading-relaxed font-normal">
            {t('about_hero_desc')}
          </p>
        </div>

        {/* GitHub Repository Spotlight Banner */}
        <div className="mb-14 rounded-3xl bg-white border border-[#EAE8DE] p-6 sm:p-10 shadow-sm transition-all hover:shadow-md">
          <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-8">
            <div className="space-y-4 max-w-2xl">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-2xl bg-slate-900 text-white">
                  <svg className="h-6 w-6 fill-current" viewBox="0 0 24 24">
                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
                  </svg>
                </div>
                <div>
                  <h2 className="text-xl sm:text-2xl font-bold text-slate-900">
                    {t('about_github_title')}
                  </h2>
                  <span className="text-xs font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-0.5 rounded-full border border-emerald-200">
                    {t('about_github_stars')}
                  </span>
                </div>
              </div>

              <p className="text-sm sm:text-base text-slate-600 leading-relaxed">
                {t('about_github_desc')}
              </p>

              <div className="flex flex-wrap gap-2 text-xs text-slate-500 pt-1">
                <span className="px-2.5 py-1 rounded-lg bg-stone-100 font-mono">apps/mobile (Flutter)</span>
                <span className="px-2.5 py-1 rounded-lg bg-stone-100 font-mono">apps/api (NestJS)</span>
                <span className="px-2.5 py-1 rounded-lg bg-stone-100 font-mono">apps/backoffice (Next.js)</span>
                <span className="px-2.5 py-1 rounded-lg bg-stone-100 font-mono">apps/portal (Next.js)</span>
              </div>
            </div>

            <div className="shrink-0">
              <a
                href="https://github.com/lajuapp/laju"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2.5 rounded-2xl bg-slate-900 px-6 py-4 text-sm font-semibold text-white shadow-lg hover:bg-slate-800 transition-all hover:scale-[1.02] active:scale-[0.98]"
              >
                <span>{t('about_github_btn')}</span>
                <ExternalLink className="h-4 w-4" />
              </a>
            </div>
          </div>
        </div>

        {/* Business Source License 1.1 Section */}
        <div className="mb-14">
          <div className="max-w-2xl mb-8">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight mb-2">
              {t('about_license_box_title')}
            </h2>
            <p className="text-slate-600 text-sm sm:text-base">
              {t('about_license_box_sub')}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Pillar 1: Permitted Use */}
            <div className="rounded-2xl bg-white border border-[#EAE8DE] p-6 shadow-xs space-y-3">
              <div className="h-10 w-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
                <CheckCircle2 className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">
                {t('about_grant_title')}
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-normal">
                {t('about_grant_desc')}
              </p>
            </div>

            {/* Pillar 2: Network Reciprocity (Section 13) */}
            <div className="rounded-2xl bg-white border border-[#EAE8DE] p-6 shadow-xs space-y-3">
              <div className="h-10 w-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                <Globe className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">
                {t('about_restriction_title')}
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-normal">
                {t('about_restriction_desc')}
              </p>
            </div>

            {/* Pillar 3: Commercial Dual-Licensing */}
            <div className="rounded-2xl bg-white border border-[#EAE8DE] p-6 shadow-xs space-y-3">
              <div className="h-10 w-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
                <Building2 className="h-5 w-5" />
              </div>
              <h3 className="text-base font-bold text-slate-900">
                {t('about_sunset_title')}
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-normal">
                {t('about_sunset_desc')}
              </p>
            </div>
          </div>
        </div>

        {/* Trademark & Infrastructure Notice */}
        <div className="rounded-2xl border border-stone-200 bg-white/70 p-6 sm:p-8 backdrop-blur-xs">
          <div className="flex items-start gap-4">
            <div className="p-2 rounded-xl bg-[#0D382C]/10 text-[#0D382C] shrink-0 mt-0.5">
              <ShieldCheck className="h-5 w-5" />
            </div>
            <div className="space-y-1.5 text-left">
              <h3 className="text-base font-bold text-slate-900">
                {t('about_trademark_title')}
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                {t('about_trademark_desc')}
              </p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
