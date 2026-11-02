'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Download, ExternalLink, Smartphone, Users, CheckCircle, ArrowRight } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';

interface SmartRedirectorProps {
  type: 'group' | 'user' | 'call';
  code: string;
  title: string;
  subtitle?: string;
  memberCount?: number;
  avatarUrl?: string;
}

export function SmartRedirector({
  type,
  code,
  title,
  subtitle,
  memberCount,
  avatarUrl,
}: SmartRedirectorProps) {
  const { t } = useLanguage();
  const [hasAttempted, setHasAttempted] = useState(false);
  const [isAndroid, setIsAndroid] = useState(false);

  // Scheme and intent URLs
  const cleanCode = encodeURIComponent(code);
  const path = type === 'group' ? `join/${cleanCode}` : type === 'user' ? `u/${cleanCode}` : `call/${cleanCode}`;
  const customScheme = `laju://${path}`;
  const androidIntent = `intent://${path}#Intent;scheme=laju;package=com.laju.laju_mobile;end`;

  useEffect(() => {
    // Detect platform
    const userAgent = navigator.userAgent || navigator.vendor || (window as any).opera;
    const android = /android/i.test(userAgent);
    setIsAndroid(android);

    // Auto-launch intent after short delay
    const timer = setTimeout(() => {
      setHasAttempted(true);
      try {
        if (android) {
          window.location.href = androidIntent;
        } else {
          window.location.href = customScheme;
        }
      } catch (_) {}
    }, 400);

    return () => clearTimeout(timer);
  }, [androidIntent, customScheme]);

  const handleManualOpen = () => {
    if (isAndroid) {
      window.location.href = androidIntent;
    } else {
      window.location.href = customScheme;
    }
  };

  return (
    <div className="mx-auto max-w-lg px-4 py-16 sm:py-24 text-center">
      <div className="rounded-[2.5rem] border border-stone-200/80 bg-white p-8 sm:p-10 shadow-xl soft-shadow text-left">
        {/* Avatar or Icon */}
        <div className="relative mx-auto mb-6 flex h-24 w-24 items-center justify-center rounded-3xl bg-[#EEF3EF] border-2 border-[#C1D5C8] overflow-hidden shadow-inner">
          {avatarUrl ? (
            <img src={avatarUrl} alt={title} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-3xl font-black text-[#0D382C]">
              {type === 'group' ? (
                <Users className="h-10 w-10 text-[#0D382C]" />
              ) : (
                <Smartphone className="h-10 w-10 text-[#0D382C]" />
              )}
            </div>
          )}
        </div>

        {/* Title */}
        <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight text-center">
          {title || t('redirect_group_title')}
        </h1>

        {/* Subtitle / Description */}
        <p className="mt-2 text-sm text-slate-600 text-center">
          {subtitle || (type === 'group' ? t('redirect_group_subtitle') : t('redirect_user_subtitle'))}
        </p>

        {memberCount !== undefined && memberCount > 0 && (
          <div className="mt-3 flex justify-center">
            <span className="inline-flex items-center gap-1.5 rounded-full bg-[#EEF3EF] border border-[#C1D5C8] px-3 py-1 text-xs text-[#0D382C] font-bold">
              <Users className="h-3.5 w-3.5 text-[#0D382C]" />
              <span>{t('redirect_member_count').replace('{count}', String(memberCount))}</span>
            </span>
          </div>
        )}

        {/* Primary Action Button */}
        <div className="mt-8 space-y-3">
          <button
            onClick={handleManualOpen}
            className="w-full flex items-center justify-center gap-2 rounded-2xl bg-laju-500 hover:bg-laju-600 py-4 px-6 text-sm font-bold text-white shadow-mint-glow hover:shadow-mint-glow-sm hover:-translate-y-0.5 transition-all active:translate-y-0"
          >
            <Smartphone className="h-4 w-4" />
            {t('redirect_open_app')}
          </button>

          <Link
            href="/download"
            className="w-full flex items-center justify-center gap-2 rounded-2xl border border-[#EAE8DE] bg-[#F5F4EF] py-3.5 px-6 text-xs font-semibold text-slate-700 hover:bg-[#EAE8DE] hover:text-slate-900 transition-all shadow-sm"
          >
            <Download className="h-4 w-4 text-[#0D382C]" />
            {t('redirect_download_prompt')}
          </Link>
        </div>

        {/* Security Assurance */}
        <div className="mt-6 border-t border-[#EAE8DE]/70 pt-4 text-[11px] text-slate-400 flex items-center justify-center gap-1.5 font-medium">
          <CheckCircle className="h-3.5 w-3.5 text-[#0D382C]" />
          <span>{t('redirect_secure_note')}</span>
        </div>
      </div>
    </div>
  );
}
