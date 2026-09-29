import React from 'react';
import { clsx } from 'clsx';

interface BadgeProps {
  children: React.ReactNode;
  variant?: 'success' | 'warning' | 'error' | 'neutral' | 'brand';
  size?: 'sm' | 'md';
}

export function Badge({ children, variant = 'neutral', size = 'sm' }: BadgeProps) {
  const variantStyles = {
    success: 'bg-brand-50 text-brand-800 border-brand-200/90 font-medium',
    warning: 'bg-amber-50 text-amber-700 border-amber-200/80',
    error: 'bg-rose-50 text-rose-700 border-rose-200/80',
    neutral: 'bg-neutral-100 text-neutral-700 border-neutral-200/80',
    brand: 'bg-brand-50 text-brand-800 border-brand-300 font-semibold',
  }[variant];

  const sizeStyles = {
    sm: 'text-[11px] px-2 py-0.5',
    md: 'text-xs px-2.5 py-1',
  }[size];

  return (
    <span
      className={clsx(
        'inline-flex items-center font-medium rounded-full border',
        variantStyles,
        sizeStyles
      )}
    >
      {children}
    </span>
  );
}
