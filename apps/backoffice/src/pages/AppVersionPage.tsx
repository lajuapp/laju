import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Settings2,
  CheckCircle,
  AlertCircle,
  Smartphone,
  ShieldAlert,
  Save,
} from 'lucide-react';
import { useAppConfig, useUpdateAppConfig } from '../hooks/useAppConfig';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';

const appConfigSchema = z.object({
  minAndroidVersion: z.string().min(1, 'Versi minimum tidak boleh kosong'),
  latestAndroidVersion: z.string().min(1, 'Versi terbaru tidak boleh kosong'),
  forceUpdate: z.boolean().default(false),
  maintenanceMode: z.boolean().default(false),
  maintenanceMessage: z.string().optional(),
});

type AppConfigFormValues = z.infer<typeof appConfigSchema>;

export function AppVersionPage() {
  const { data: config, isLoading } = useAppConfig();
  const updateConfig = useUpdateAppConfig();

  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<AppConfigFormValues>({
    resolver: zodResolver(appConfigSchema),
    defaultValues: {
      minAndroidVersion: '1.0.0',
      latestAndroidVersion: '1.0.0',
      forceUpdate: false,
      maintenanceMode: false,
      maintenanceMessage: '',
    },
  });

  useEffect(() => {
    if (config) {
      reset({
        minAndroidVersion: config.minAndroidVersion || '1.0.0',
        latestAndroidVersion: config.latestAndroidVersion || '1.0.0',
        forceUpdate: config.forceUpdate || false,
        maintenanceMode: config.maintenanceMode || false,
        maintenanceMessage: config.maintenanceMessage || '',
      });
    }
  }, [config, reset]);

  const onSubmit = async (data: AppConfigFormValues) => {
    try {
      setErrorMessage(null);
      setSuccessMessage(null);
      await updateConfig.mutateAsync(data);
      setSuccessMessage('Konfigurasi versi aplikasi berhasil disimpan');
      setTimeout(() => setSuccessMessage(null), 4000);
    } catch (err: any) {
      setErrorMessage(
        err.response?.data?.message || 'Gagal menyimpan konfigurasi aplikasi'
      );
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
          Pengaturan Versi Aplikasi & Pemeliharaan (App Version Control)
        </h1>
        <p className="text-xs text-neutral-500 mt-1">
          Atur versi aktif aplikasi, batas pembaruan wajib, dan kontrol status pemeliharaan sistem
        </p>
      </div>

      {successMessage && (
        <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-200/80 text-emerald-800 text-xs flex items-center gap-2.5 shadow-xs">
          <CheckCircle className="w-4 h-4 text-emerald-600 flex-shrink-0" />
          <span className="font-semibold">{successMessage}</span>
        </div>
      )}

      {errorMessage && (
        <div className="p-3.5 rounded-2xl bg-rose-50 border border-rose-200/80 text-rose-800 text-xs flex items-center gap-2.5 shadow-xs">
          <AlertCircle className="w-4 h-4 text-rose-600 flex-shrink-0" />
          <span className="font-semibold">{errorMessage}</span>
        </div>
      )}

      {isLoading ? (
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-8 text-center text-xs text-neutral-400">
          Memuat konfigurasi sistem...
        </div>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          {/* Card 1: Versi Aplikasi */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <Smartphone className="w-4 h-4 text-neutral-700" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Distribusi & Versi Aplikasi Android
              </h2>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <Input
                  label="Versi Minimum Wajib (Min Version)"
                  placeholder="Contoh: 1.0.0"
                  {...register('minAndroidVersion')}
                  error={errors.minAndroidVersion?.message}
                />
                <p className="text-[11px] text-neutral-400 mt-1">
                  Aplikasi dengan versi lebih rendah tidak dapat digunakan jika pembaruan wajib aktif
                </p>
              </div>

              <div>
                <Input
                  label="Versi Terbaru Tersedia (Latest Version)"
                  placeholder="Contoh: 1.0.5"
                  {...register('latestAndroidVersion')}
                  error={errors.latestAndroidVersion?.message}
                />
                <p className="text-[11px] text-neutral-400 mt-1">
                  Nomor versi publik yang direkomendasikan kepada pengguna
                </p>
              </div>
            </div>

            <div className="pt-2">
              <label className="flex items-start gap-3 p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 cursor-pointer hover:bg-neutral-50 transition-colors">
                <input
                  type="checkbox"
                  {...register('forceUpdate')}
                  className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4 mt-0.5"
                />
                <div>
                  <p className="text-xs font-bold text-neutral-900">
                    Wajibkan Pembaruan Aplikasi (Force Update)
                  </p>
                  <p className="text-[11px] text-neutral-500 mt-0.5">
                    Jika diaktifkan, pengguna dengan versi di bawah batas minimum tidak dapat mengakses beranda sampai melakukan update.
                  </p>
                </div>
              </label>
            </div>
          </div>

          {/* Card 2: Mode Pemeliharaan (Maintenance Mode) */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <ShieldAlert className="w-4 h-4 text-neutral-700" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Mode Pemeliharaan Sistem (Maintenance Mode)
              </h2>
            </div>

            <div>
              <label className="flex items-start gap-3 p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 cursor-pointer hover:bg-neutral-50 transition-colors">
                <input
                  type="checkbox"
                  {...register('maintenanceMode')}
                  className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4 mt-0.5"
                />
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-xs font-bold text-neutral-900">
                      Aktifkan Mode Pemeliharaan
                    </p>
                    <Badge variant="warning">Akses Dibatasi</Badge>
                  </div>
                  <p className="text-[11px] text-neutral-500 mt-0.5">
                    Ketika mode ini aktif, seluruh interaksi baru pada aplikasi mobile akan ditangguhkan sementara dengan menampilkan pesan pemeliharaan di bawah.
                  </p>
                </div>
              </label>
            </div>

            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                Pesan Pemeliharaan Untuk Pengguna
              </label>
              <textarea
                {...register('maintenanceMessage')}
                rows={3}
                placeholder="Contoh: Sistem sedang dalam pemeliharaan berkala untuk peningkatan performa. Silakan coba kembali beberapa saat lagi."
                className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
              />
            </div>
          </div>

          {/* Submit Action */}
          <div className="flex justify-end">
            <Button
              type="submit"
              variant="primary"
              icon={<Save className="w-4 h-4" />}
              isLoading={updateConfig.isPending}
            >
              Simpan Konfigurasi
            </Button>
          </div>
        </form>
      )}
    </div>
  );
}
