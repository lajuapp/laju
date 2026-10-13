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
        message: res.message || 'Database reset operation completed successfully.',
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
        message: err.response?.data?.message || err.message || 'Failed to execute database reset.',
      });
    }
  };

  const handleQuickReseed = async () => {
    try {
      setFeedback(null);
      const res = await reseedMutation.mutateAsync();
      setFeedback({
        type: 'success',
        message: res.message || 'Default seed data applied successfully. Wallpaper & Sticker assets remain intact!',
        details: res.results,
      });
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.response?.data?.message || err.message || 'Failed to reseed default data.',
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
                Data Maintenance & Dev Tools
              </h1>
              <p className="text-xs text-neutral-500 mt-0.5">
                Maintenance utilities and data purge tools for development and staging environments.
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
            Refresh Counts
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={handleQuickReseed}
            isLoading={reseedMutation.isPending}
            icon={<Sparkles className="w-3.5 h-3.5 text-brand-600" />}
          >
            Reseed Default Assets
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
          Current Database Record Counts
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3.5">
          {/* Users & Devices */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Users className="w-4 h-4 text-brand-600" />
              <Badge variant="brand">{stats?.totalUsers ?? 0} Accounts</Badge>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalUsers ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">
              {stats?.totalDevices ?? 0} Registered Devices
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
            <p className="text-[11px] text-neutral-500 mt-0.5">Personal chats</p>
          </div>

          {/* Group Chats */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Layers className="w-4 h-4 text-purple-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Groups</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalGroupConversations ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Active groups</p>
          </div>

          {/* Messages */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <MessageSquare className="w-4 h-4 text-emerald-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Total Messages</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalMessages ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Encrypted messages</p>
          </div>

          {/* User Stories */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Sparkles className="w-4 h-4 text-amber-500" />
              <span className="text-[10px] font-semibold text-neutral-500">Stories</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalStories ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">User stories</p>
          </div>

          {/* Calls */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <PhoneCall className="w-4 h-4 text-cyan-600" />
              <span className="text-[10px] font-semibold text-neutral-500">Calls</span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalCalls ?? 0}
            </div>
            <p className="text-[11px] text-neutral-500 mt-0.5">Call history logs</p>
          </div>

          {/* Wallpapers (Protected) */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs bg-gradient-to-br from-white to-emerald-50/20">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <ImageIcon className="w-4 h-4 text-teal-600" />
              <span className="text-[10px] font-extrabold uppercase tracking-wide text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Fixed Asset
              </span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalWallpapers ?? 0}
            </div>
            <p className="text-[11px] text-emerald-600 font-medium mt-0.5">
              Wallpapers (Protected)
            </p>
          </div>

          {/* Stickers (Protected) */}
          <div className="bg-white p-4 rounded-xl border border-neutral-200/80 shadow-2xs bg-gradient-to-br from-white to-emerald-50/20">
            <div className="flex items-center justify-between text-neutral-400 mb-2">
              <Smile className="w-4 h-4 text-amber-500" />
              <span className="text-[10px] font-extrabold uppercase tracking-wide text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Fixed Asset
              </span>
            </div>
            <div className="text-xl font-bold text-neutral-900">
              {stats?.totalStickerPacks ?? 0} Packs
            </div>
            <p className="text-[11px] text-emerald-600 font-medium mt-0.5">
              {stats?.totalStickers ?? 0} Stickers (Protected)
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
            Fixed Asset Protection: Wallpapers & Stickers Are Safeguarded
          </h3>
          <p className="text-xs text-neutral-600 mt-1 leading-relaxed">
            Per LAJU architecture, all <strong>Chat Wallpapers</strong> and <strong>Sticker Packs</strong> are treated as <em>fixed system assets</em>. Resetting chat logs, stories, groups, or running <strong>Reseed Defaults</strong> will <u>never delete</u> your wallpaper and sticker libraries.
          </p>
        </div>
      </div>

      {/* Main Reset Form Section */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-2xs overflow-hidden">
        <div className="px-6 py-5 border-b border-neutral-100 flex items-center justify-between">
          <div>
            <h2 className="text-sm font-extrabold text-neutral-900">
              Granular Reset Options
            </h2>
            <p className="text-xs text-neutral-500 mt-0.5">
              Select specific data categories you wish to purge
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
                  Reset 1-on-1 Direct Chats
                </span>
                <Badge variant="neutral">{stats?.totalDirectConversations ?? 0} Chats</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Purge all personal conversations, messages, media attachments, reactions, and delivery records.
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
                  Reset Group Chats & Memberships
                </span>
                <Badge variant="neutral">{stats?.totalGroupConversations ?? 0} Groups</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Purge all group rooms, member rosters, and group message logs.
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
                  Reset User Stories / Statuses
                </span>
                <Badge variant="neutral">{stats?.totalStories ?? 0} Stories</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Purge all user-published stories and view records.
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
                  Reset Call History Logs
                </span>
                <Badge variant="neutral">{stats?.totalCalls ?? 0} Calls</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Clear all voice and video call log entries.
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
                  Reset User Statuses to ACTIVE (Unsuspend All Users)
                </span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Restore previously suspended or deactivated user accounts back to ACTIVE and clear suspension reasons.
              </p>
            </div>
          </label>

          {/* Option: Wipe All Users */}
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
                  Purge Test User Accounts (Wipe Test Users & Devices)
                </span>
                <span className="text-[10px] font-bold text-amber-800 bg-amber-100 px-2 py-0.5 rounded-md border border-amber-300">
                  Wipe Tester Data
                </span>
              </div>
              <p className="text-[11px] text-amber-800 mt-0.5 leading-relaxed">
                Purge all regular client tester accounts, device sessions, and Signal cryptokeys.
                <strong className="ml-1 text-neutral-900">Admin accounts will not be deleted.</strong>
              </p>
            </div>
          </label>

          {/* Option: Auto Reseed Defaults */}
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
                  Auto Re-seed Default System Data (Roles, Permissions, & Built-in Assets)
                </span>
                <Badge variant="brand">Recommended</Badge>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Ensures system access privileges, roles, and default assets remain synchronized after reset.
              </p>
            </div>
          </label>

          {/* Advanced / Forced Asset Deletion */}
          <div className="pt-4 border-t border-neutral-100">
            <div className="flex items-center gap-2 mb-3">
              <Lock className="w-3.5 h-3.5 text-neutral-400" />
              <h3 className="text-xs font-bold text-neutral-700 uppercase tracking-wider">
                Special Asset Purge (Danger Zone - Protected)
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
                    Force Delete All Chat Wallpapers
                  </span>
                  <p className="text-[11px] text-rose-800 mt-0.5">
                    Only check this option if you explicitly intend to purge the wallpaper catalog.
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
                    Force Delete All Sticker Packs
                  </span>
                  <p className="text-[11px] text-rose-800 mt-0.5">
                    Only check this option if you explicitly intend to purge the sticker catalog.
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
                Options selected. Click the button to review and execute.
              </span>
            ) : (
              <span>Select at least one option above to enable reset.</span>
            )}
          </div>

          <Button
            variant="danger"
            size="md"
            disabled={!hasAnySelection}
            onClick={handleOpenConfirmModal}
            icon={<Trash2 className="w-4 h-4" />}
          >
            Review & Execute Reset
          </Button>
        </div>
      </div>

      {/* Confirmation Modal */}
      <Modal
        isOpen={isConfirmModalOpen}
        onClose={() => setIsConfirmModalOpen(false)}
        title="Confirm Database Reset Operation"
        description="Carefully review the operations listed below before proceeding."
        maxWidth="md"
      >
        <div className="space-y-4 pt-2">
          <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-900 text-xs flex items-start gap-2.5">
            <AlertTriangle className="w-4 h-4 text-rose-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-bold">Warning: This action is permanent!</p>
              <p className="mt-0.5 text-rose-800">
                Selected data will be deleted from the database and cannot be recovered.
              </p>
            </div>
          </div>

          <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200 text-xs space-y-2">
            <p className="font-bold text-neutral-700">Scheduled Operations:</p>
            <ul className="list-disc pl-5 space-y-1 text-neutral-600 text-[11px]">
              {resetChats && <li>Delete all 1-on-1 private conversations and messages</li>}
              {resetGroups && <li>Delete all group chats and message histories</li>}
              {resetUserStatuses && <li>Delete all user stories</li>}
              {resetCalls && <li>Delete all call history logs</li>}
              {resetUserAccountStatuses && <li>Reset all user account statuses to ACTIVE</li>}
              {wipeAllUsers && <li className="text-rose-600 font-bold">Wipe all test user accounts and devices</li>}
              {reseedDefaults && <li className="text-emerald-700 font-medium">Synchronize / reseed default data</li>}
              {deleteWallpapers && <li className="text-rose-600 font-bold">Delete all chat wallpapers</li>}
              {deleteStickers && <li className="text-rose-600 font-bold">Delete all sticker packs</li>}
            </ul>
          </div>

          <div>
            <label className="block text-xs font-bold text-neutral-800 mb-1.5">
              Type <span className="font-mono text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">RESET</span> to confirm:
            </label>
            <Input
              type="text"
              placeholder="Type RESET here"
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
              Cancel
            </Button>
            <Button
              variant="danger"
              size="sm"
              disabled={confirmInput.trim().toUpperCase() !== 'RESET'}
              isLoading={resetMutation.isPending}
              onClick={handleExecuteReset}
              icon={<Trash2 className="w-3.5 h-3.5" />}
            >
              Execute Reset
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
