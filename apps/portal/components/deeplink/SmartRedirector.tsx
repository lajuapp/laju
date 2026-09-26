'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Download, ExternalLink, Smartphone, Users, CheckCircle, ArrowRight } from 'lucide-react';

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
      <div className="rounded-3xl border border-white/10 bg-slate-900/80 p-8 sm:p-10 backdrop-blur-xl shadow-2xl">
        {/* Avatar or Icon */}
        <div className="relative mx-auto mb-6 flex h-24 w-24 items-center justify-center rounded-3xl bg-brand-500/10 border-2 border-brand-500/30 overflow-hidden shadow-xl">
          {avatarUrl ? (
            <img src={avatarUrl} alt={title} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-3xl font-black text-brand-400">
              {type === 'group' ? (
                <Users className="h-10 w-10 text-brand-400" />
              ) : (
                <Smartphone className="h-10 w-10 text-brand-400" />
              )}
            </div>
          )}
        </div>

        {/* Title */}
        <h1 className="text-2xl sm:text-3xl font-black text-white tracking-tight">
          {title}
        </h1>

        {/* Subtitle / Description */}
        <p className="mt-2 text-sm text-slate-300">
          {subtitle || (type === 'group' ? 'Undangan bergabung ke grup percakapan LAJU' : 'Tautan percakapan LAJU')}
        </p>

        {memberCount !== undefined && memberCount > 0 && (
          <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-white/5 border border-white/10 px-3 py-1 text-xs text-slate-300 font-medium">
            <Users className="h-3.5 w-3.5 text-brand-400" />
            <span>{memberCount} Anggota Terdaftar</span>
          </div>
        )}

        {/* Primary Action Button */}
        <div className="mt-8 space-y-3">
          <button
            onClick={handleManualOpen}
            className="w-full flex items-center justify-center gap-2 rounded-2xl bg-brand-500 py-3.5 px-6 text-sm font-extrabold text-slate-950 shadow-lg shadow-brand-500/25 hover:bg-brand-400 transition-all active:scale-95"
          >
            <Smartphone className="h-4 w-4" />
            Buka di Aplikasi LAJU
          </button>

          <Link
            href="/download"
            className="w-full flex items-center justify-center gap-2 rounded-2xl border border-white/10 bg-white/5 py-3 px-6 text-xs font-semibold text-slate-300 hover:bg-white/10 transition-all"
          >
            <Download className="h-4 w-4 text-brand-400" />
            Belum punya aplikasi? Unduh LAJU (.APK)
          </Link>
        </div>

        {/* Security Assurance */}
        <div className="mt-6 border-t border-white/5 pt-4 text-[11px] text-slate-400 flex items-center justify-center gap-1.5">
          <CheckCircle className="h-3.5 w-3.5 text-brand-400" />
          <span>Tautan resmi terlindungi enkripsi end-to-end LAJU</span>
        </div>
      </div>
    </div>
  );
}
