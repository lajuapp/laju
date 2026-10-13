import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  CheckCircle,
  AlertCircle,
  Smartphone,
  ShieldAlert,
  Save,
  UploadCloud,
  FileArchive,
  Download,
  Hash,
  FileCheck,
} from 'lucide-react';
import { useAppConfig, useUpdateAppConfig, useUploadApk } from '../hooks/useAppConfig';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';

const appConfigSchema = z.object({
  minAndroidVersion: z.string().min(1, 'Minimum version cannot be empty'),
  latestAndroidVersion: z.string().min(1, 'Latest version cannot be empty'),
  forceUpdate: z.boolean().default(false),
  maintenanceMode: z.boolean().default(false),
  maintenanceMessage: z.string().optional(),
});

type AppConfigFormValues = z.infer<typeof appConfigSchema>;

export function AppVersionPage() {
  const { data: config, isLoading } = useAppConfig();
  const updateConfig = useUpdateAppConfig();
  const uploadApkMutation = useUploadApk();

  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // APK Upload States
  const [selectedApkFile, setSelectedApkFile] = useState<File | null>(null);
  const [apkVersionInput, setApkVersionInput] = useState<string>('');
  const [apkMinVersionInput, setApkMinVersionInput] = useState<string>('');
  const [apkReleaseNotes, setApkReleaseNotes] = useState<string>('');
  const [apkForceUpdate, setApkForceUpdate] = useState<boolean>(false);
  const [apkUploadSuccess, setApkUploadSuccess] = useState<string | null>(null);
  const [apkUploadError, setApkUploadError] = useState<string | null>(null);
  const [isUploadingApk, setIsUploadingApk] = useState<boolean>(false);
  const [uploadProgress, setUploadProgress] = useState<number>(0);

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

      if (!apkVersionInput) {
        setApkVersionInput(config.latestAndroidVersion || '1.0.0');
      }
      if (!apkMinVersionInput) {
        setApkMinVersionInput(config.minAndroidVersion || '1.0.0');
      }
      if (config.forceUpdate !== undefined) {
        setApkForceUpdate(config.forceUpdate);
      }
    }
  }, [config, reset]);

  const onSubmit = async (data: AppConfigFormValues) => {
    try {
      setErrorMessage(null);
      setSuccessMessage(null);
      await updateConfig.mutateAsync(data);
      setSuccessMessage('Application version configuration saved successfully');
      setTimeout(() => setSuccessMessage(null), 4000);
    } catch (err: any) {
      setErrorMessage(
        err.response?.data?.message || 'Failed to save application configuration'
      );
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!file.name.toLowerCase().endsWith('.apk')) {
        setApkUploadError('File must have an .apk extension');
        setSelectedApkFile(null);
        return;
      }
      setApkUploadError(null);
      setSelectedApkFile(file);
    }
  };

  const handleUploadApkSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedApkFile) {
      setApkUploadError('Please select an APK file first');
      return;
    }

    try {
      setIsUploadingApk(true);
      setUploadProgress(0);
      setApkUploadError(null);
      setApkUploadSuccess(null);

      const res = await uploadApkMutation.mutateAsync({
        file: selectedApkFile,
        version: apkVersionInput || '1.0.0',
        minVersion: apkMinVersionInput || undefined,
        forceUpdate: apkForceUpdate,
        releaseNotes: apkReleaseNotes || undefined,
        onProgress: (percent) => {
          setUploadProgress(percent);
        },
      });

      setApkUploadSuccess(res.message || 'APK file successfully uploaded and released!');
      setSelectedApkFile(null);
      setUploadProgress(0);
      setTimeout(() => setApkUploadSuccess(null), 6000);
    } catch (err: any) {
      setApkUploadError(
        err.response?.data?.message || err.message || 'Failed to upload APK file'
      );
      setUploadProgress(0);
    } finally {
      setIsUploadingApk(false);
    }
  };

  const formatFileSize = (bytes?: number | null) => {
    if (!bytes) return '0 B';
    const mb = bytes / (1024 * 1024);
    if (mb >= 1) return `${mb.toFixed(1)} MB`;
    const kb = bytes / 1024;
    return `${kb.toFixed(0)} KB`;
  };

  const apiBase = import.meta.env.VITE_API_URL || '';
  const downloadApkUrl = `${apiBase}/admin/app-config/download-apk`;

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div>
        <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
          App Versioning & Package Distribution
        </h1>
        <p className="text-xs text-neutral-500 mt-1">
          Upload mobile APK binaries directly, manage release version numbers, and oversee system maintenance modes.
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

      {/* SECTION 1: UPLOAD APK */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-6">
        <div className="flex items-center justify-between border-b border-neutral-100 pb-3">
          <div className="flex items-center gap-2.5">
            <UploadCloud className="w-5 h-5 text-brand-600" />
            <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
              Android APK Binary Distribution
            </h2>
          </div>
          {config?.apkFilename && (
            <Badge variant="success">APK Ready for Download</Badge>
          )}
        </div>

        {/* Current Active APK Info Card */}
        {config?.apkFilename ? (
          <div className="p-4 rounded-xl bg-neutral-50/80 border border-neutral-200/70 space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-brand-500/10 text-brand-600">
                  <FileArchive className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-neutral-900">
                      {config.apkFilename}
                    </span>
                    <Badge variant="brand">v{config.latestAndroidVersion}</Badge>
                  </div>
                  <div className="text-[11px] text-neutral-500 mt-0.5 flex flex-wrap gap-2">
                    <span>Size: {formatFileSize(config.apkSize)}</span>
                    <span>•</span>
                    <span>Updated: {new Date(config.updatedAt).toLocaleDateString('en-US')}</span>
                  </div>
                </div>
              </div>

              <a
                href={downloadApkUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-neutral-200 text-xs font-semibold text-neutral-700 hover:bg-neutral-50 shadow-xs transition-colors"
              >
                <Download className="w-3.5 h-3.5 text-brand-600" />
                <span>Download File</span>
              </a>
            </div>

            {config.apkSha256 && (
              <div className="text-[10px] font-mono text-neutral-400 bg-white/80 p-2 rounded-lg border border-neutral-200/50 flex items-center gap-1.5 overflow-hidden">
                <Hash className="w-3 h-3 text-neutral-400 shrink-0" />
                <span className="text-neutral-500 font-semibold shrink-0">SHA-256:</span>
                <span className="truncate">{config.apkSha256}</span>
              </div>
            )}

            {config.releaseNotes && (
              <div className="text-xs text-neutral-600 bg-white/80 p-2.5 rounded-lg border border-neutral-200/50">
                <span className="font-semibold text-neutral-700 block mb-0.5">Release Notes:</span>
                <p className="whitespace-pre-wrap">{config.releaseNotes}</p>
              </div>
            )}
          </div>
        ) : (
          <div className="p-4 rounded-xl bg-amber-50/70 border border-amber-200/70 text-amber-800 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-amber-600 shrink-0" />
            <span>No APK file uploaded yet. Upload your first release binary using the form below.</span>
          </div>
        )}

        {/* Upload Form */}
        <form onSubmit={handleUploadApkSubmit} className="space-y-4 pt-2">
          {apkUploadSuccess && (
            <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center gap-2.5">
              <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
              <span className="font-semibold">{apkUploadSuccess}</span>
            </div>
          )}

          {apkUploadError && (
            <div className="p-3.5 rounded-2xl bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-center gap-2.5">
              <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
              <span className="font-semibold">{apkUploadError}</span>
            </div>
          )}

          <div className="border-2 border-dashed border-neutral-200 hover:border-brand-500 rounded-2xl p-6 text-center transition-colors bg-neutral-50/50">
            <input
              type="file"
              id="apk-file-input"
              accept=".apk"
              onChange={handleFileChange}
              className="hidden"
            />
            <label htmlFor="apk-file-input" className="cursor-pointer block">
              <div className="flex justify-center mb-2">
                <div className="p-3 rounded-2xl bg-brand-50 text-brand-600">
                  <FileCheck className="w-8 h-8" />
                </div>
              </div>
              {selectedApkFile ? (
                <div>
                  <p className="text-xs font-bold text-neutral-900">{selectedApkFile.name}</p>
                  <p className="text-[11px] text-brand-600 font-semibold mt-0.5">
                    {formatFileSize(selectedApkFile.size)} • Ready to upload
                  </p>
                  <p className="text-[10px] text-neutral-400 mt-1">Click to change file</p>
                </div>
              ) : (
                <div>
                  <p className="text-xs font-bold text-neutral-900">
                    Select or drag Android APK (.apk) file here
                  </p>
                  <p className="text-[11px] text-neutral-400 mt-1">
                    Maximum file size up to 500 MB (Streaming multipart)
                  </p>
                </div>
              )}
            </label>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                New Release Version
              </label>
              <Input
                placeholder="e.g. 1.0.1"
                value={apkVersionInput}
                onChange={(e) => setApkVersionInput(e.target.value)}
              />
              <p className="text-[10px] text-neutral-400 mt-1">
                Will be recorded as the latest Android client version
              </p>
            </div>

            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                Minimum Supported Version
              </label>
              <Input
                placeholder="e.g. 1.0.0"
                value={apkMinVersionInput}
                onChange={(e) => setApkMinVersionInput(e.target.value)}
              />
              <p className="text-[10px] text-neutral-400 mt-1">
                Lowest version permitted to access network endpoints
              </p>
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
              Release Notes
            </label>
            <textarea
              rows={2}
              placeholder="Summary of new features or security updates in this release..."
              value={apkReleaseNotes}
              onChange={(e) => setApkReleaseNotes(e.target.value)}
              className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
            />
          </div>

          <div>
            <label className="flex items-start gap-3 p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 cursor-pointer hover:bg-neutral-50 transition-colors">
              <input
                type="checkbox"
                checked={apkForceUpdate}
                onChange={(e) => setApkForceUpdate(e.target.checked)}
                className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4 mt-0.5"
              />
              <div>
                <p className="text-xs font-bold text-neutral-900">
                  Enforce Immediate Update (Force Update)
                </p>
                <p className="text-[11px] text-neutral-500 mt-0.5">
                  Clients on older versions cannot proceed until downloading this update.
                </p>
              </div>
            </label>
          </div>

          {/* Upload Progress Indicator */}
          {isUploadingApk && (
            <div className="space-y-1.5 p-3.5 rounded-2xl bg-brand-50 border border-brand-200 shadow-xs">
              <div className="flex justify-between items-center text-xs font-bold text-brand-900">
                <span className="flex items-center gap-1.5">
                  <UploadCloud className="w-4 h-4 text-brand-600 animate-pulse" />
                  Uploading APK binary to server...
                </span>
                <span className="font-mono text-xs bg-white px-2 py-0.5 rounded-full border border-brand-200 text-brand-800">
                  {uploadProgress}%
                </span>
              </div>
              <div className="w-full bg-brand-200/60 rounded-full h-2.5 overflow-hidden">
                <div
                  className="bg-brand-600 h-2.5 rounded-full transition-all duration-200 ease-out"
                  style={{ width: `${Math.max(uploadProgress, 2)}%` }}
                />
              </div>
              <p className="text-[10px] text-brand-700">
                Direct binary streaming without browser memory buffering. Please keep this tab open.
              </p>
            </div>
          )}

          <div className="flex justify-end pt-2">
            <Button
              type="submit"
              variant="primary"
              icon={<UploadCloud className="w-4 h-4" />}
              isLoading={isUploadingApk}
              disabled={!selectedApkFile || isUploadingApk}
            >
              {isUploadingApk ? `Uploading (${uploadProgress}%)...` : 'Upload & Publish APK'}
            </Button>
          </div>
        </form>
      </div>

      {/* SECTION 2: CONFIGURATION & MAINTENANCE */}
      {isLoading ? (
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-8 text-center text-xs text-neutral-400">
          Loading system configuration...
        </div>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          {/* Card: Version Policy */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <Smartphone className="w-4 h-4 text-brand-600" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Version Policy & Enforcement
              </h2>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                  Latest Version
                </label>
                <Input
                  {...register('latestAndroidVersion')}
                  placeholder="e.g. 1.0.1"
                />
                {errors.latestAndroidVersion && (
                  <p className="text-[10px] text-rose-500 mt-1">{errors.latestAndroidVersion.message}</p>
                )}
                <p className="text-[10px] text-neutral-400 mt-1">
                  Target client version currently offered to users
                </p>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                  Minimum Supported Version
                </label>
                <Input
                  {...register('minAndroidVersion')}
                  placeholder="e.g. 1.0.0"
                />
                {errors.minAndroidVersion && (
                  <p className="text-[10px] text-rose-500 mt-1">{errors.minAndroidVersion.message}</p>
                )}
                <p className="text-[10px] text-neutral-400 mt-1">
                  Clients below this version will be blocked from authenticating
                </p>
              </div>
            </div>

            <div>
              <label className="flex items-start gap-3 p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 cursor-pointer hover:bg-neutral-50 transition-colors">
                <input
                  type="checkbox"
                  {...register('forceUpdate')}
                  className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4 mt-0.5"
                />
                <div>
                  <p className="text-xs font-bold text-neutral-900">
                    Enforce Mandatory Update (Force Update)
                  </p>
                  <p className="text-[11px] text-neutral-500 mt-0.5">
                    When active, users running older builds will be required to update before accessing conversations.
                  </p>
                </div>
              </label>
            </div>
          </div>

          {/* Card: Maintenance Mode */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <ShieldAlert className="w-4 h-4 text-neutral-700" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                System Maintenance Mode
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
                      Enable Maintenance Mode
                    </p>
                    <Badge variant="warning">Restricted Access</Badge>
                  </div>
                  <p className="text-[11px] text-neutral-500 mt-0.5">
                    When active, new mobile requests will be temporarily suspended with the maintenance notice below.
                  </p>
                </div>
              </label>
            </div>

            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                User Maintenance Message
              </label>
              <textarea
                {...register('maintenanceMessage')}
                rows={3}
                placeholder="e.g. System is undergoing scheduled maintenance for performance upgrades. Please check back shortly."
                className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
              />
            </div>

            <div className="flex justify-end pt-2">
              <Button
                type="submit"
                variant="primary"
                icon={<Save className="w-4 h-4" />}
                isLoading={updateConfig.isPending}
              >
                Save Policies & Maintenance
              </Button>
            </div>
          </div>
        </form>
      )}
    </div>
  );
}
