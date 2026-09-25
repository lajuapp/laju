import React, { useState, useEffect } from 'react';
import { AlertCircle, AlertTriangle, HelpCircle, X } from 'lucide-react';
import { Button } from './Button';

interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: (inputValue?: string) => void;
  title: string;
  description: string;
  confirmText?: string;
  cancelText?: string;
  variant?: 'danger' | 'warning' | 'primary';
  requiresInput?: boolean;
  inputLabel?: string;
  inputPlaceholder?: string;
  initialInputValue?: string;
  isLoading?: boolean;
}

export function ConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  title,
  description,
  confirmText = 'Konfirmasi',
  cancelText = 'Batal',
  variant = 'danger',
  requiresInput = false,
  inputLabel,
  inputPlaceholder,
  initialInputValue = '',
  isLoading = false,
}: ConfirmModalProps) {
  const [inputValue, setInputValue] = useState(initialInputValue);

  useEffect(() => {
    if (isOpen) {
      setInputValue(initialInputValue);
    }
  }, [isOpen, initialInputValue]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !isLoading) onClose();
    };
    if (isOpen) {
      document.body.style.overflow = 'hidden';
      window.addEventListener('keydown', handleKeyDown);
    }
    return () => {
      document.body.style.overflow = 'unset';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen, onClose, isLoading]);

  if (!isOpen) return null;

  const handleConfirm = (e: React.FormEvent) => {
    e.preventDefault();
    onConfirm(requiresInput ? inputValue : undefined);
  };

  const iconConfig = {
    danger: {
      icon: AlertCircle,
      iconBg: 'bg-rose-50 text-rose-600 border-rose-200/80',
      btnVariant: 'danger' as const,
    },
    warning: {
      icon: AlertTriangle,
      iconBg: 'bg-amber-50 text-amber-600 border-amber-200/80',
      btnVariant: 'outline' as const,
    },
    primary: {
      icon: HelpCircle,
      iconBg: 'bg-neutral-100 text-neutral-800 border-neutral-200/80',
      btnVariant: 'primary' as const,
    },
  }[variant];

  const IconComponent = iconConfig.icon;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-neutral-900/40 backdrop-blur-sm transition-opacity"
        onClick={() => {
          if (!isLoading) onClose();
        }}
      />

      {/* Modal Card */}
      <div className="relative w-full max-w-md bg-white rounded-2xl border border-neutral-200/90 shadow-2xl z-10 overflow-hidden transform transition-all animate-in fade-in zoom-in-95 duration-150">
        <form onSubmit={handleConfirm}>
          <div className="p-6">
            <div className="flex items-start gap-4">
              <div
                className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 border ${iconConfig.iconBg}`}
              >
                <IconComponent className="w-5 h-5" />
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-bold text-neutral-900">{title}</h3>
                  <button
                    type="button"
                    onClick={onClose}
                    disabled={isLoading}
                    className="p-1 -mr-1 -mt-1 rounded-lg text-neutral-400 hover:text-neutral-700 hover:bg-neutral-100 transition-colors disabled:opacity-50"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
                <p className="text-xs text-neutral-500 mt-1 leading-relaxed">
                  {description}
                </p>

                {requiresInput && (
                  <div className="mt-4">
                    {inputLabel && (
                      <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                        {inputLabel}
                      </label>
                    )}
                    <textarea
                      value={inputValue}
                      onChange={(e) => setInputValue(e.target.value)}
                      placeholder={inputPlaceholder}
                      rows={2}
                      disabled={isLoading}
                      className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
                    />
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-2.5 px-6 py-3.5 bg-neutral-50/80 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={onClose}
              disabled={isLoading}
            >
              {cancelText}
            </Button>
            <Button
              type="submit"
              variant={iconConfig.btnVariant}
              size="sm"
              isLoading={isLoading}
            >
              {confirmText}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
