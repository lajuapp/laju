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
  ExternalLink,
  Globe,
} from 'lucide-react';
import { useAppConfig, useUpdateAppConfig, useUploadApk } from '../hooks/useAppConfig';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';

const appConfigSchema = z.object({
  minAndroidVersion: z.string().min(1, 'Minimum Android version cannot be empty'),
  latestAndroidVersion: z.string().min(1, 'Latest Android version cannot be empty'),
  minIosVersion: z.string().optional(),
  latestIosVersion: z.string().optional(),
  playStoreUrl: z.string().optional(),
  appStoreUrl: z.string().optional(),
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

  // APK Upload States (for internal sideloading & testing)
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
      minIosVersion: '1.0.0',
      latestIosVersion: '1.0.0',
      playStoreUrl: '',
      appStoreUrl: '',
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
        minIosVersion: config.minIosVersion || config.minAndroidVersion || '1.0.0',
        latestIosVersion: config.latestIosVersion || config.latestAndroidVersion || '1.0.0',
        playStoreUrl: config.playStoreUrl || '',
        appStoreUrl: config.appStoreUrl || '',
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
      setSuccessMessage('Store links and version policies saved successfully');
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

      setApkUploadSuccess(res.message || 'APK file successfully uploaded and recorded for test sideloading!');
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
          App Versioning & Store Distribution
        </h1>
        <p className="text-xs text-neutral-500 mt-1">
          Configure official Google Play Store and Apple App Store redirection URLs, manage client minimum/latest versions, and enforce maintenance windows.
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

      {/* SECTION 1: OFFICIAL STORE REDIRECTION & VERSION POLICIES */}
      {isLoading ? (
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-8 text-center text-xs text-neutral-400">
          Loading system configuration...
        </div>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          {/* Card: Official Store URLs */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <Globe className="w-4 h-4 text-brand-600" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Official App Store Redirection Links
              </h2>
            </div>

            <p className="text-xs text-neutral-500">
              When an update is detected, mobile clients will display an update reminder with a direct button that redirects users to these store URLs. If left empty, default store package identifiers will be used.
            </p>

            <div className="space-y-4">
              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                  Google Play Store URL / Intent
                </label>
                <Input
                  {...register('playStoreUrl')}
                  placeholder="market://details?id=com.laju.mobile (Default)"
                />
                <p className="text-[10px] text-neutral-400 mt-1">
                  Default: <code className="bg-neutral-100 px-1 py-0.5 rounded text-neutral-600">market://details?id=com.laju.mobile</code> (opens Google Play app directly, falls back to web)
                </p>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                  Apple App Store URL
                </label>
                <Input
                  {...register('appStoreUrl')}
                  placeholder="https://apps.apple.com/app/laju/id... (Default)"
                />
                <p className="text-[10px] text-neutral-400 mt-1">
                  iOS client will redirect users directly to this Apple App Store link.
                </p>
              </div>
            </div>
          </div>

          {/* Card: Version Policy & Enforcement */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-5">
            <div className="flex items-center gap-2.5 border-b border-neutral-100 pb-3">
              <Smartphone className="w-4 h-4 text-brand-600" />
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Version Enforcement Policy
              </h2>
            </div>

            {/* Android Version Controls */}
            <div>
              <h3 className="text-xs font-bold text-neutral-800 mb-2">Android Version Targets</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                    Latest Android Version
                  </label>
                  <Input
                    {...register('latestAndroidVersion')}
                    placeholder="e.g. 1.0.12"
                  />
                  {errors.latestAndroidVersion && (
                    <p className="text-[10px] text-rose-500 mt-1">{errors.latestAndroidVersion.message}</p>
                  )}
                  <p className="text-[10px] text-neutral-400 mt-1">
                    Users on older versions will see the update reminder prompt
                  </p>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                    Minimum Supported Android Version
                  </label>
                  <Input
                    {...register('minAndroidVersion')}
                    placeholder="e.g. 1.0.0"
                  />
                  {errors.minAndroidVersion && (
                    <p className="text-[10px] text-rose-500 mt-1">{errors.minAndroidVersion.message}</p>
                  )}
                  <p className="text-[10px] text-neutral-400 mt-1">
                    Clients below this version will be blocked by Mandatory Force Update
                  </p>
                </div>
              </div>
            </div>

            {/* iOS Version Controls */}
            <div className="pt-2 border-t border-neutral-100">
              <h3 className="text-xs font-bold text-neutral-800 mb-2">iOS Version Targets</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                    Latest iOS Version
                  </label>
                  <Input
                    {...register('latestIosVersion')}
                    placeholder="e.g. 1.0.12"
                  />
                  <p className="text-[10px] text-neutral-400 mt-1">
                    Target iOS release version currently offered to users
                  </p>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                    Minimum Supported iOS Version
                  </label>
                  <Input
                    {...register('minIosVersion')}
                    placeholder="e.g. 1.0.0"
                  />
                  <p className="text-[10px] text-neutral-400 mt-1">
                    iOS clients below this version will be blocked by Mandatory Force Update
                  </p>
                </div>
              </div>
            </div>

            <div className="pt-2 border-t border-neutral-100">
              <label className="flex items-start gap-3 p-3 rounded-xl bg-neutral-50/70 border border-neutral-200/60 cursor-pointer hover:bg-neutral-50 transition-colors">
                <input
                  type="checkbox"
                  {...register('forceUpdate')}
                  className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4 mt-0.5"
                />
                <div>
                  <p className="text-xs font-bold text-neutral-900">
                    Enforce Mandatory Update (Force Update for all older builds)
                  </p>
                  <p className="text-[11px] text-neutral-500 mt-0.5">
                    When active, users running any version lower than the Latest Version will not have the "Later" option and must update via the store to proceed.
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
                Save Store Settings & Policies
              </Button>
            </div>
          </div>
        </form>
      )}

      {/* SECTION 2: INTERNAL TESTING & DIRECT APK SIDELOADING (OPTIONAL / DEV) */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs p-6 space-y-6">
        <div className="flex items-center justify-between border-b border-neutral-100 pb-3">
          <div className="flex items-center gap-2.5">
            <UploadCloud className="w-5 h-5 text-neutral-600" />
            <div>
              <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
                Internal Testing & Direct APK Sideloading (Dev / QA)
              </h2>
              <p className="text-[11px] text-neutral-400">
                Optional tool for uploading test APK builds to object storage for development sideloading.
              </p>
            </div>
          </div>
          {config?.apkFilename && (
            <Badge variant="neutral">Test APK Active</Badge>
          )}
        </div>

        {/* Current Active APK Info Card */}
        {config?.apkFilename ? (
          <div className="p-4 rounded-xl bg-neutral-50/80 border border-neutral-200/70 space-y-3">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-neutral-200 text-neutral-700">
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
                <Download className="w-3.5 h-3.5 text-neutral-600" />
                <span>Download Test File</span>
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
          <div className="p-4 rounded-xl bg-neutral-50 border border-neutral-200 text-neutral-600 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-neutral-400 shrink-0" />
            <span>No test APK uploaded yet. If needed for testing, you can upload a direct binary below.</span>
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

          <div className="border-2 border-dashed border-neutral-200 hover:border-neutral-400 rounded-2xl p-6 text-center transition-colors bg-neutral-50/50">
            <input
              type="file"
              id="apk-file-input"
              accept=".apk"
              onChange={handleFileChange}
              className="hidden"
            />
            <label htmlFor="apk-file-input" className="cursor-pointer block">
              <div className="flex justify-center mb-2">
                <div className="p-3 rounded-2xl bg-neutral-100 text-neutral-600">
                  <FileCheck className="w-8 h-8" />
                </div>
              </div>
              {selectedApkFile ? (
                <div>
                  <p className="text-xs font-bold text-neutral-900">{selectedApkFile.name}</p>
                  <p className="text-[11px] text-neutral-600 font-semibold mt-0.5">
                    {formatFileSize(selectedApkFile.size)} • Ready to upload
                  </p>
                  <p className="text-[10px] text-neutral-400 mt-1">Click to change file</p>
                </div>
              ) : (
                <div>
                  <p className="text-xs font-bold text-neutral-900">
                    Select Android APK (.apk) file for internal testing
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
                Test Release Version
              </label>
              <Input
                placeholder="e.g. 1.0.12"
                value={apkVersionInput}
                onChange={(e) => setApkVersionInput(e.target.value)}
              />
            </div>

            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1 uppercase tracking-wider">
                Release Notes
              </label>
              <Input
                placeholder="e.g. Internal QA test build"
                value={apkReleaseNotes}
                onChange={(e) => setApkReleaseNotes(e.target.value)}
              />
            </div>
          </div>

          {/* Upload Progress Indicator */}
          {isUploadingApk && (
            <div className="space-y-1.5 p-3.5 rounded-2xl bg-neutral-100 border border-neutral-200 shadow-xs">
              <div className="flex justify-between items-center text-xs font-bold text-neutral-900">
                <span className="flex items-center gap-1.5">
                  <UploadCloud className="w-4 h-4 text-neutral-600 animate-pulse" />
                  Uploading test APK binary to server...
                </span>
                <span className="font-mono text-xs bg-white px-2 py-0.5 rounded-full border border-neutral-200 text-neutral-800">
                  {uploadProgress}%
                </span>
              </div>
              <div className="w-full bg-neutral-200 rounded-full h-2.5 overflow-hidden">
                <div
                  className="bg-neutral-800 h-2.5 rounded-full transition-all duration-200 ease-out"
                  style={{ width: `${Math.max(uploadProgress, 2)}%` }}
                />
              </div>
            </div>
          )}

          <div className="flex justify-end pt-2">
            <Button
              type="submit"
              variant="secondary"
              icon={<UploadCloud className="w-4 h-4" />}
              isLoading={isUploadingApk}
              disabled={!selectedApkFile || isUploadingApk}
            >
              {isUploadingApk ? `Uploading (${uploadProgress}%)...` : 'Upload Test APK'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
