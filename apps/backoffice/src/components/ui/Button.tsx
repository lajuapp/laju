import React from 'react';
import { clsx } from 'clsx';
import { Loader2 } from 'lucide-react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost' | 'outline';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
  icon?: React.ReactNode;
}

export function Button({
  children,
  variant = 'primary',
  size = 'md',
  isLoading = false,
  icon,
  className,
  disabled,
  ...props
}: ButtonProps) {
  const variantStyles = {
    primary: 'bg-neutral-900 text-white hover:bg-neutral-800 active:bg-neutral-950 border border-transparent shadow-sm',
    secondary: 'bg-neutral-100 text-neutral-800 hover:bg-neutral-200 active:bg-neutral-300 border border-neutral-200/80',
    outline: 'bg-white text-neutral-700 hover:bg-neutral-50 active:bg-neutral-100 border border-neutral-200 shadow-sm',
    danger: 'bg-rose-600 text-white hover:bg-rose-700 active:bg-rose-800 border border-transparent shadow-sm',
    ghost: 'bg-transparent text-neutral-600 hover:bg-neutral-100 active:bg-neutral-200',
  }[variant];

  const sizeStyles = {
    sm: 'text-xs px-2.5 py-1.5 rounded-lg gap-1.5 font-medium',
    md: 'text-xs px-3.5 py-2 rounded-lg gap-2 font-medium',
    lg: 'text-sm px-4 py-2.5 rounded-xl gap-2 font-semibold',
  }[size];

  return (
    <button
      disabled={disabled || isLoading}
      className={clsx(
        'inline-flex items-center justify-center transition-all select-none disabled:opacity-50 disabled:cursor-not-allowed active:scale-[0.98]',
        variantStyles,
        sizeStyles,
        className
      )}
      {...props}
    >
      {isLoading ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : icon}
      {children}
    </button>
  );
}
