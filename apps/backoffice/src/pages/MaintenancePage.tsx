import React, { useState } from 'react';
import {
  Database,
  RefreshCw,
  Trash2,
  ShieldCheck,
  AlertTriangle,
  Users,
  MessageSquare,
  Sparkles,
  PhoneCall,
  Image as ImageIcon,
  Smile,
  CheckCircle,
  HelpCircle,
  Layers,
  Lock,
} from 'lucide-react';
import { useMaintenanceStats, useMaintenanceReset, useReseedDefaults } from '../hooks/useMaintenance';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';

export function MaintenancePage() {
  const { data: stats, isLoading: loadingStats, refetch } = useMaintenanceStats();
  const resetMutation = useMaintenanceReset();
  const reseedMutation = useReseedDefaults();

  // Reset Option States
  const [resetChats, setResetChats] = useState(false);
  const [resetGroups, setResetGroups] = useState(false);
  const [resetUserStatuses, setResetUserStatuses] = useState(false);
  const [resetCalls, setResetCalls] = useState(false);
  const [resetUserAccountStatuses, setResetUserAccountStatuses] = useState(false);
  const [wipeAllUsers, setWipeAllUsers] = useState(false);
  const [reseedDefaults, setReseedDefaults] = useState(true);

  // Advanced / Fixed Assets Deletion (Off by default for safety)
  const [deleteWallpapers, setDeleteWallpapers] = useState(false);
  const [deleteStickers, setDeleteStickers] = useState(false);

  // Modal & Confirmation States
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [confirmInput, setConfirmInput] = useState('');
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string; details?: any } | null>(null);

  const hasAnySelection =
    resetChats ||
    resetGroups ||
    resetUserStatuses ||
    resetCalls ||
    resetUserAccountStatuses ||
    wipeAllUsers ||
    deleteWallpapers ||
    deleteStickers;

  const handleOpenConfirmModal = () => {
    if (!hasAnySelection) return;
    setConfirmInput('');
    setIsConfirmModalOpen(true);
  };

  const handleExecuteReset = async () => {
    if (confirmInput.trim().toUpperCase() !== 'RESET') return;

    try {
      setFeedback(null);
      const res = await resetMutation.mutateAsync({
        resetChats,
        resetGroups,
        resetUserStatuses,
        resetCalls,
        resetUserAccountStatuses,
        wipeAllUsers,
        reseedDefaults,
        deleteWallpapers,
        deleteStickers,
        confirmationCode: confirmInput.trim(),
      });

      setIsConfirmModalOpen(false);
      setFeedback({
        type: 'success',
        message: res.message || 'Reset data berhasil dijalankan.',
        details: res.results,
      });

      // Reset selection form
      setResetChats(false);
      setResetGroups(false);
      setResetUserStatuses(false);
      setResetCalls(false);
      setResetUserAccountStatuses(false);
      setWipeAllUsers(false);
      setDeleteWallpapers(false);
      setDeleteStickers(false);
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.message || err.message || 'Gagal menjalankan reset data.',
      });
    }
  };

  const handleQuickReseed = async () => {
    try {
      setFeedback(null);
      const res = await reseedMutation.mutateAsync();
      setFeedback({
        type: 'success',
        message: res.message || 'Re-seed data default berhasil. Seluruh aset Wallpaper & Stiker tetap aman!',
        details: res.results,
      });
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.message || err.message || 'Gagal menjalankan re-seed data default.',
      });
    }
  };

  return (
    <div className="space-y-6 max-w-6xl mx-auto pb-12">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-brand-50 border border-brand-200 flex items-center justify-center text-brand-600 shadow-2xs">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
                Pemeliharaan Data & Dev Tools
              </h1>
              <p className="text-xs text-neutral-500 mt-0.5">
                Pengelolaan dan peresetan data obrolan, grup, status, dan pengguna untuk kebutuhan development & staging
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            isLoading={loadingStats}
            icon={<RefreshCw className="w-3.5 h-3.5" />}
          >
            Segarkan Statistik
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={handleQuickReseed}
            isLoading={reseedMutation.isPending}
            icon={<Sparkles className="w-3.5 h-3.5 text-brand-600" />}
          >
            Re-seed Data Default
          </Button>
        </div>
      </div>

      {/* Alert Feedback */}
      {feedback && (
        <div
          className={`p-4 rounded-xl border flex items-start gap-3 text-xs ${
            feedback.type === 'success'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-900'
              : 'bg-rose-50 border-rose-200 text-rose-900'
          }`}
        >
          {feedback.type === 'success' ? (
            <CheckCircle className="w-4 h-4 text-emerald-600 flex-shrink-0 mt-0.5" />
          ) : (
            <AlertTriangle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
          )}
          <div className="space-y-1 flex-1">
            <p className="font-semibold">{feedback.message}</p>
            {feedback.details && (
              <pre className="bg-white/80 p-2.5 rounded-lg border border-neutral-200 text-[11px] font-mono overflow-x-auto text-neutral-700 mt-2">
                {JSON.stringify(feedback.details, null, 2)}
              </pre>
            )}
          </div>
          <button
            onClick={() => setFeedback(null)}
            className="text-neutral-400 hover:text-neutral-600 font-bold ml-2"
          >
            ✕
          </button>
        </div>
      )}

      {/* Database Overview Cards */}
      <div>
        <h2 className="text-xs font-bold text-neutral-500 uppercase tracking-wider mb-3">
          Ringkasan Data Saat Ini di Database
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3.5">
          {/* Users & Devices */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Users className="w-4 h-4 text-brand-600" />
              <Badge variant="brand">{stats?.totalUsers ?? 0} Akun</Badge>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalUsers ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">
              {stats?.totalDevices ?? 0} Perangkat terdaftar
            </p>
          </div>

          {/* Direct Chats */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <MessageSquare className="w-4 h-4 text-blue-600" />
              <span className="text-[10px] font-semibold text-neutral-500">1-on-1 Chats</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalDirectConversations ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Percakapan personal</p>
          </div>

          {/* Group Chats */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Layers className="w-4 h-4 text-purple-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Grup</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalGroupConversations ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Grup aktif</p>
          </div>

          {/* Messages */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <MessageSquare className="w-4 h-4 text-emerald-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Total Pesan</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalMessages ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Pesan terenkripsi</p>
          </div>

          {/* User Stories */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Sparkles className="w-4 h-4 text-amber-500" />
              <span className="text-[10px] font-semibold text-neutral-500">Status</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalStories ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Story pengguna</p>
          </div>

          {/* Calls */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <PhoneCall className="w-4 h-4 text-cyan-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Panggilan</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalCalls ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Riwayat call logs</p>
          </div>

          {/* Wallpapers (Protected) */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs bg-gradient-to-br from-white to-emerald-50/20">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <ImageIcon className="w-4 h-4 text-teal-600" />
              <span className="text-[10px] font-extrabold uppercase tracking-wide text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Aset Fix
              </span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalWallpapers ?? 0}
            </div>
            <p className="text-[11px] text-emerald-600 font-medium mt-0.5">
              Wallpaper (Dilindungi)
            </p>
          </div>

          {/* Stickers (Protected) */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs bg-gradient-to-br from-white to-emerald-50/20">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Smile className="w-4 h-4 text-amber-500" />
              <span className="text-[10px] font-extrabold uppercase tracking-wide text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Aset Fix
              </span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalStickerPacks ?? 0} Pack
            </div>
            <p className="text-[11px] text-emerald-600 font-medium mt-0.5">
              {stats?.totalStickers ?? 0} Stiker (Dilindungi)
            </p>
          </div>
        </div>
      </div>

      {/* Protection Notice Banner */}
      <div className="p-4 rounded-2xl bg-gradient-to-r from-emerald-500/10 via-brand-500/10 to-teal-500/10 border border-emerald-300/40 flex items-start gap-3.5 shadow-2xs">
        <div className="w-8 h-8 rounded-xl bg-emerald-100 flex items-center justify-center text-emerald-700 flex-shrink-0 mt-0.5">
          <ShieldCheck className="w-5 h-5" />
        </div>
        <div>
          <h3 className="text-xs font-bold text-neutral-900">
            Proteksi Aset Tetap: Wallpaper & Stiker Dijamin Aman
          </h3>
          <p className="text-xs text-neutral-600 mt-1 leading-relaxed">
            Sesuai arsitektur LAJU, seluruh berkas <strong>Wallpaper Obrolan</strong> dan <strong>Paket Stiker</strong> dianggap sebagai <em>aset sistem tetap (fix)</em>.
            Menjalankan reset data obrolan, status, grup, maupun proses <strong>Re-seed Database</strong> <u>tidak akan pernah mendelete</u> wallpaper dan stiker Anda.
          </p>
        </div>
      </div>

      {/* Main Reset Form Section */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-2xs overflow-hidden">
        <div className="px-6 py-5 border-b border-neutral-100 flex items-center justify-between">
          <div>
            <h2 className="text-sm font-extrabold text-neutral-900">
              Pilihan Peresetan Data (Granular Reset Options)
            </h2>
            <p className="text-xs text-neutral-500 mt-0.5">
              Pilih kategori data yang ingin Anda bersihkan secara spesifik
            </p>
          </div>
          <Badge variant="brand">Development Mode</Badge>
        </div>

        <div className="p-6 space-y-4">
          {/* Option: Reset Direct Chats */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={resetChats}
              onChange={(e) => setResetChats(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Reset Obrolan Personal (1-on-1 Direct Chats)
                </span>
                <Badge variant="neutral">{stats?.totalDirectConversations ?? 0} Obrolan</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Menghapus semua percakapan privat personal beserta seluruh pesan, lampiran gambar/file, reaksi pesan, dan status pengiriman (deliveries).
              </p>
            </div>
          </label>

          {/* Option: Reset Group Chats */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={resetGroups}
              onChange={(e) => setResetGroups(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Reset Grup Obrolan (Group Chats & Members)
                </span>
                <Badge variant="neutral">{stats?.totalGroupConversations ?? 0} Grup</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Menghapus seluruh grup obrolan, daftar keanggotaan grup, serta seluruh riwayat percakapan grup.
              </p>
            </div>
          </label>

          {/* Option: Reset Status Stories */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={resetUserStatuses}
              onChange={(e) => setResetUserStatuses(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Reset Status/Story Pengguna
                </span>
                <Badge variant="neutral">{stats?.totalStories ?? 0} Status</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Menghapus seluruh postingan status (story) pengguna beserta catatan penonton (views).
              </p>
            </div>
          </label>

          {/* Option: Reset Calls */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={resetCalls}
              onChange={(e) => setResetCalls(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Reset Riwayat Panggilan (Calls)
                </span>
                <Badge variant="neutral">{stats?.totalCalls ?? 0} Panggilan</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Membersihkan seluruh catatan riwayat panggilan suara & video (call logs).
              </p>
            </div>
          </label>

          {/* Option: Reset User Account Status */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={resetUserAccountStatuses}
              onChange={(e) => setResetUserAccountStatuses(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Reset Status Akun Pengguna ke AKTIF (Unsuspend All Users)
                </span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Mengembalikan status seluruh akun yang sebelumnya terblokir (SUSPENDED atau DEACTIVATED) menjadi ACTIVE, serta membersihkan riwayat alasan suspend.
              </p>
            </div>
          </label>

          {/* Option: Wipe All Users (Dev tester purge) */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-amber-300/80 bg-amber-50/30 hover:bg-amber-50/50 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={wipeAllUsers}
              onChange={(e) => setWipeAllUsers(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-amber-400 text-amber-600 focus:ring-amber-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-amber-950">
                  Hapus Semua Akun Pengguna Tester (Wipe Test Users & Devices)
                </span>
                <span className="text-[10px] font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded-md border border-amber-300">
                  Hapus Data Tester
                </span>
              </div>
              <p className="text-[11px] text-amber-800 mt-0.5 leading-relaxed">
                Menghapus seluruh akun pengguna biasa (tester), sesi login, kunci kriptografi Signal, dan perangkat terdaftar. 
                <strong className="ml-1 text-neutral-900">Akun Admin tidak akan terhapus.</strong>
              </p>
            </div>
          </label>

          {/* Option: Auto Re-seed Defaults */}
          <label className="flex items-start gap-3.5 p-3.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-50/60 cursor-pointer transition-colors">
            <input
              type="checkbox"
              checked={reseedDefaults}
              onChange={(e) => setReseedDefaults(e.target.checked)}
              className="mt-1 h-4 w-4 rounded border-neutral-300 text-brand-600 focus:ring-brand-500"
            />
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-900">
                  Re-seed Data Default Otomatis (Permissions, Roles, & Default Assets)
                </span>
                <Badge variant="brand">Direkomendasikan</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Memastikan hak akses sistem, peran admin, wallpaper default, dan paket stiker dasar selalu sinkron setelah reset selesai.
              </p>
            </div>
          </label>

          {/* Advanced / Forced Asset Deletion */}
          <div className="pt-4 border-t border-neutral-100">
            <div className="flex items-center gap-2 mb-3">
              <Lock className="w-3.5 h-3.5 text-neutral-400" />
              <h3 className="text-xs font-bold text-neutral-700 uppercase tracking-wider">
                Opsi Khusus Aset Tetap (Danger Zone - Terproteksi)
              </h3>
            </div>

            <div className="space-y-3">
              <label className="flex items-start gap-3.5 p-3 rounded-xl border border-rose-200 bg-rose-50/30 hover:bg-rose-50/60 cursor-pointer transition-colors">
                <input
                  type="checkbox"
                  checked={deleteWallpapers}
                  onChange={(e) => setDeleteWallpapers(e.target.checked)}
                  className="mt-1 h-4 w-4 rounded border-rose-400 text-rose-600 focus:ring-rose-500"
                />
                <div className="flex-1">
                  <span className="text-xs font-bold text-rose-950">
                    Paksa Hapus Seluruh Wallpaper Obrolan
                  </span>
                  <p className="text-[11px] text-rose-800 mt-0.5">
                    Hanya centang opsi ini jika Anda benar-benar berniat mengosongkan katalog wallpaper yang tersimpan saat ini.
                  </p>
                </div>
              </label>

              <label className="flex items-start gap-3.5 p-3 rounded-xl border border-rose-200 bg-rose-50/30 hover:bg-rose-50/60 cursor-pointer transition-colors">
                <input
                  type="checkbox"
                  checked={deleteStickers}
                  onChange={(e) => setDeleteStickers(e.target.checked)}
                  className="mt-1 h-4 w-4 rounded border-rose-400 text-rose-600 focus:ring-rose-500"
                />
                <div className="flex-1">
                  <span className="text-xs font-bold text-rose-950">
                    Paksa Hapus Seluruh Paket Stiker
                  </span>
                  <p className="text-[11px] text-rose-800 mt-0.5">
                    Hanya centang opsi ini jika Anda benar-benar berniat mengosongkan katalog seluruh paket stiker.
                  </p>
                </div>
              </label>
            </div>
          </div>
        </div>

        {/* Footer Action */}
        <div className="px-6 py-4 bg-neutral-50/80 border-t border-neutral-100 flex items-center justify-between">
          <div className="text-xs text-neutral-500">
            {hasAnySelection ? (
              <span className="text-neutral-900 font-semibold">
                Opsi telah dipilih. Klik tombol di kanan untuk meninjau dan mengeksekusi.
              </span>
            ) : (
              <span>Pilih setidaknya satu opsi di atas untuk mengaktifkan reset.</span>
            )}
          </div>

          <Button
            variant="danger"
            size="md"
            disabled={!hasAnySelection}
            onClick={handleOpenConfirmModal}
            icon={<Trash2 className="w-4 h-4" />}
          >
            Tinjau & Jalankan Reset Terpilih
          </Button>
        </div>
      </div>

      {/* Confirmation Modal */}
      <Modal
        isOpen={isConfirmModalOpen}
        onClose={() => setIsConfirmModalOpen(false)}
        title="Konfirmasi Tindakan Reset Data"
        description="Periksa daftar data yang akan dihapus di bawah sebelum melanjutkan."
        maxWidth="md"
      >
        <div className="space-y-4 pt-2">
          <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-900 text-xs flex items-start gap-2.5">
            <AlertTriangle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-bold">Peringatan: Tindakan ini permanen!</p>
              <p className="mt-0.5 text-rose-800">
                Data yang dipilih akan dihapus dari basis data dan tidak dapat dikembalikan.
              </p>
            </div>
          </div>

          <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200 text-xs space-y-2">
            <p className="font-bold text-neutral-700">Daftar operasi yang akan dieksekusi:</p>
            <ul className="list-disc pl-5 space-y-1 text-neutral-600 text-[11px]">
              {resetChats && <li>Hapus seluruh percakapan privat (1-on-1) dan pesan</li>}
              {resetGroups && <li>Hapus seluruh grup obrolan dan riwayat pesan grup</li>}
              {resetUserStatuses && <li>Hapus seluruh status/story pengguna</li>}
              {resetCalls && <li>Hapus seluruh catatan riwayat panggilan</li>}
              {resetUserAccountStatuses && <li>Kembalikan status semua akun user ke ACTIVE</li>}
              {wipeAllUsers && <li className="text-rose-600 font-bold">Hapus semua akun user tester dan perangkat</li>}
              {reseedDefaults && <li className="text-emerald-700 font-medium">Jalankan sinkronisasi / re-seed data default</li>}
              {deleteWallpapers && <li className="text-rose-600 font-bold">Hapus semua wallpaper obrolan</li>}
              {deleteStickers && <li className="text-rose-600 font-bold">Hapus semua paket stiker</li>}
            </ul>
          </div>

          <div>
            <label className="block text-xs font-bold text-neutral-800 mb-1.5">
              Ketik kata <span className="font-mono text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">RESET</span> untuk mengonfirmasi:
            </label>
            <Input
              type="text"
              placeholder="Ketik RESET di sini"
              value={confirmInput}
              onChange={(e) => setConfirmInput(e.target.value)}
              className="text-xs uppercase font-mono tracking-widest"
              autoFocus
            />
          </div>

          <div className="flex items-center justify-end gap-2 pt-3 border-t border-neutral-100">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsConfirmModalOpen(false)}
            >
              Batalkan
            </Button>
            <Button
              variant="danger"
              size="sm"
              disabled={confirmInput.trim().toUpperCase() !== 'RESET'}
              isLoading={resetMutation.isPending}
              onClick={handleExecuteReset}
              icon={<Trash2 className="w-3.5 h-3.5" />}
            >
              Ya, Eksekusi Reset Sekarang
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
