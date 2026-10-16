import React, { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Smartphone,
  Image as ImageIcon,
  Smile,
  ShieldAlert,
  ShieldCheck,
  LogOut,
  Sparkles,
  Settings2,
  LifeBuoy,
  Database,
  BarChart3,
  Key,
  AlertCircle,
  CheckCircle,
  Eye,
  EyeOff,
  Copy,
  Check,
} from 'lucide-react';

import { useAdminMe, useLogout, useChangePassword } from '../../hooks/useAdminAuth';
import { useDashboardStats } from '../../hooks/useDashboardStats';
import { Badge } from '../ui/Badge';
import { Modal } from '../ui/Modal';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { clsx } from 'clsx';

export function AppLayout() {
  const navigate = useNavigate();
  const { data: admin, isLoading } = useAdminMe();
  const { data: stats } = useDashboardStats();
  const logout = useLogout();
  const changePassword = useChangePassword();

  // Change Password Modal State
  const [isPasswordModalOpen, setIsPasswordModalOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPasswords, setShowPasswords] = useState(false);
  const [copied, setCopied] = useState(false);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null);

  React.useEffect(() => {
    const token = localStorage.getItem('laju_admin_token');
    if (!token && !isLoading) {
      navigate('/login');
    }
  }, [navigate, isLoading]);

  const handleOpenPasswordModal = () => {
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setShowPasswords(false);
    setCopied(false);
    setPasswordError(null);
    setPasswordSuccess(null);
    setIsPasswordModalOpen(true);
  };

  const handleGeneratePassword = () => {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*';
    let generated = '';
    for (let i = 0; i < 14; i++) {
      generated += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setNewPassword(generated);
    setConfirmPassword(generated);
    setShowPasswords(true);

    navigator.clipboard.writeText(generated).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 3000);
    });
  };

  const handleChangePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError(null);
    setPasswordSuccess(null);

    if (!currentPassword) {
      setPasswordError('Password saat ini wajib diisi');
      return;
    }

    if (!newPassword || newPassword.length < 6) {
      setPasswordError('Password baru minimal 6 karakter');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('Konfirmasi password tidak cocok');
      return;
    }

    changePassword.mutate(
      { currentPassword, newPassword },
      {
        onSuccess: (res: any) => {
          setPasswordSuccess(
            res?.message || 'Password berhasil diperbarui. Sesi lain telah dicabut.'
          );
          setTimeout(() => {
            setIsPasswordModalOpen(false);
          }, 1500);
        },
        onError: (err: any) => {
          setPasswordError(
            err.response?.data?.message || 'Gagal mengubah password akun'
          );
        },
      }
    );
  };

  const navGroups = [
    {
      group: 'Main',
      items: [
        { label: 'Dashboard', to: '/', icon: LayoutDashboard },
        { label: 'Service Statistics', to: '/service-stats', icon: BarChart3 },
      ],
    },
    {
      group: 'Content',
      items: [
        { label: 'Chat Wallpapers', to: '/wallpapers', icon: ImageIcon },
        { label: 'Stickers & Packs', to: '/stickers', icon: Smile },
        { label: 'Official Announcements', to: '/announcements', icon: Sparkles },
      ],
    },
    {
      group: 'System Settings',
      items: [
        { label: 'App Versioning', to: '/app-version', icon: Settings2 },
        { label: 'Data Maintenance', to: '/maintenance', icon: Database },
      ],
    },
    {
      group: 'Service & Compliance',
      items: [
        { label: 'Support Tickets', to: '/tickets', icon: LifeBuoy },
        { label: 'User Reports', to: '/reports', icon: ShieldCheck },
        { label: 'Activity Audit Logs', to: '/security', icon: ShieldAlert },
      ],
    },
    {
      group: 'Access & Users',
      items: [
        { label: 'Admin Team', to: '/admins', icon: ShieldCheck },
        { label: 'User Directory', to: '/users', icon: Users },
        { label: 'Devices', to: '/devices', icon: Smartphone },
      ],
    },
  ];

  return (
    <div className="min-h-screen bg-[radial-gradient(ellipse_80%_80%_at_50%_-20%,rgba(0,200,150,0.05),rgba(248,250,252,1))] flex text-neutral-900 font-sans selection:bg-brand-100 selection:text-brand-900">
      {/* Sidebar */}
      <aside className="w-64 bg-white/95 backdrop-blur-md border-r border-neutral-200/80 flex flex-col fixed inset-y-0 z-30 shadow-[1px_0_10px_rgba(0,0,0,0.02)]">
        {/* Brand Header */}
        <div className="h-16 flex items-center gap-3 px-5 border-b border-neutral-100/90">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-[#070D12] via-[#0F1A24] to-[#052C28] p-1.5 flex items-center justify-center shadow-xs shadow-brand-500/15 border border-brand-500/30 flex-shrink-0 transition-transform hover:scale-105">
            <img
              src="/images/logo_no_bg.png"
              alt="LAJU"
              className="w-full h-full object-contain filter drop-shadow-xs"
            />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-black text-sm tracking-tight text-neutral-900">
                LAJU
              </span>
              <span className="text-[10px] font-extrabold uppercase tracking-wider text-brand-700 bg-brand-50 px-2 py-0.5 rounded-full border border-brand-200 shadow-2xs">
                Backoffice
              </span>
            </div>
            <p className="text-[11px] text-neutral-400 font-medium">Enterprise Admin Console</p>
          </div>
        </div>

        {/* Navigation Items Grouped */}
        <nav className="flex-1 px-3 py-3 space-y-4 overflow-y-auto">
          {navGroups.map((group, gIdx) => (
            <div key={gIdx} className="space-y-1">
              <div className="px-3 pb-1 text-[10px] font-bold uppercase tracking-wider text-neutral-400">
                {group.group}
              </div>
              {group.items.map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    end={item.to === '/'}
                    className={({ isActive }) =>
                      clsx(
                        'flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all group relative',
                        isActive
                          ? 'bg-brand-50/90 text-brand-900 border border-brand-200/90 shadow-2xs font-bold'
                          : 'text-neutral-600 hover:text-neutral-900 hover:bg-neutral-100/70'
                      )
                    }
                  >
                    {({ isActive }) => (
                      <>
                        {isActive && (
                          <span className="absolute left-1 w-1 h-3.5 bg-brand-500 rounded-full" />
                        )}
                        <Icon
                          className={clsx(
                            'w-4 h-4 transition-colors',
                            isActive ? 'text-brand-600' : 'text-neutral-400 group-hover:text-neutral-700'
                          )}
                        />
                        <span className="flex-1 text-left">{item.label}</span>
                        {item.to === '/reports' && (stats?.trustAndSafety?.pendingReportsCount ?? 0) > 0 && (
                          <span className="ml-auto px-1.5 py-0.2 rounded-full text-[10px] font-extrabold bg-rose-600 text-white">
                            {stats?.trustAndSafety?.pendingReportsCount}
                          </span>
                        )}
                      </>
                    )}
                  </NavLink>
                );
              })}
            </div>
          ))}
        </nav>

        {/* User Profile & Actions Footer */}
        <div className="p-3 border-t border-neutral-100 bg-neutral-50/60">
          <div className="flex items-center justify-between p-2 rounded-xl bg-white border border-neutral-200/80 shadow-2xs">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="relative">
                <div className="w-8 h-8 rounded-lg bg-brand-50 text-brand-800 border border-brand-200 flex items-center justify-center font-bold text-xs uppercase flex-shrink-0">
                  {admin?.name?.substring(0, 2) || 'AD'}
                </div>
                <span className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full bg-brand-500 border-2 border-white" />
              </div>
              <div className="min-w-0">
                <p className="text-xs font-bold text-neutral-900 truncate">
                  {admin?.name || 'Administrator'}
                </p>
                <div className="flex items-center gap-1 mt-0.5">
                  <Badge variant="brand" size="sm">
                    {typeof admin?.role === 'string' ? admin.role : (admin?.role as any)?.name || 'Admin'}
                  </Badge>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-0.5">
              {/* Change Password Button */}
              <button
                onClick={handleOpenPasswordModal}
                title="Change My Password"
                className="p-1.5 rounded-lg text-neutral-400 hover:text-amber-600 hover:bg-amber-50 transition-colors"
              >
                <Key className="w-3.5 h-3.5" />
              </button>

              {/* Logout Button */}
              <button
                onClick={() => logout.mutate()}
                title="Logout"
                className="p-1.5 rounded-lg text-neutral-400 hover:text-rose-600 hover:bg-rose-50 transition-colors"
              >
                <LogOut className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 pl-64 flex flex-col min-h-screen">
        {/* Top Header */}
        <header className="h-16 bg-white/70 backdrop-blur-xl border-b border-neutral-200/60 sticky top-0 z-20 flex items-center justify-between px-8 shadow-[0_1px_3px_rgba(0,0,0,0.02)]">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 px-2.5 py-1 rounded-full bg-brand-50/80 border border-brand-200/80 text-[11px] font-semibold text-brand-800 shadow-2xs">
              <span className="w-2 h-2 rounded-full bg-brand-500 animate-pulse" />
              <span>Platform Node Active</span>
            </div>
            <span className="text-xs text-neutral-400">•</span>
            <span className="text-xs font-medium text-neutral-500">
              LAJU Secure Messenger Network
            </span>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 text-xs text-neutral-500 font-mono bg-neutral-100/80 px-2.5 py-1 rounded-lg border border-neutral-200/60">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
              <span>v1.0.0-prod</span>
            </div>
          </div>
        </header>

        {/* Page Body */}
        <main className="flex-1 p-8">
          <Outlet />
        </main>
      </div>

      {/* Change My Password Modal */}
      <Modal
        isOpen={isPasswordModalOpen}
        onClose={() => setIsPasswordModalOpen(false)}
        title="Change My Admin Password"
        description="Update your administrator login credentials and maintain high security assurance."
      >
        {passwordError && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{passwordError}</span>
          </div>
        )}

        {passwordSuccess && (
          <div className="mb-4 p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0 text-emerald-600" />
            <span>{passwordSuccess}</span>
          </div>
        )}

        {/* Informative Security Context */}
        <div className="mb-4 p-3 rounded-xl bg-neutral-50 border border-neutral-200/80 text-neutral-600 text-[11px] leading-relaxed flex items-start gap-2.5">
          <ShieldCheck className="w-4 h-4 text-brand-600 flex-shrink-0 mt-0.5" />
          <span>
            Your active session on this device will remain logged in. Sessions on other browsers or devices will be automatically revoked upon password update.
          </span>
        </div>

        <form onSubmit={handleChangePasswordSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1">
              Current Password
            </label>
            <Input
              type={showPasswords ? 'text' : 'password'}
              placeholder="Enter current password"
              value={currentPassword}
              onChange={(e) => setCurrentPassword(e.target.value)}
              className="font-mono text-xs"
            />
          </div>

          <div className="space-y-1">
            <div className="flex items-center justify-between">
              <label className="block text-xs font-semibold text-neutral-700">
                New Password
              </label>
              <button
                type="button"
                onClick={handleGeneratePassword}
                className="text-[11px] font-bold text-brand-700 hover:text-brand-800 flex items-center gap-1 px-2 py-0.5 rounded-lg bg-brand-50 hover:bg-brand-100 transition-colors"
              >
                <Sparkles className="w-3 h-3 text-brand-600" />
                <span>Generate Strong Key</span>
                {copied ? (
                  <span className="text-[10px] text-emerald-600 flex items-center gap-0.5 ml-1 font-semibold">
                    <Check className="w-3 h-3" /> Copied!
                  </span>
                ) : (
                  <Copy className="w-3 h-3 text-neutral-400 ml-0.5" />
                )}
              </button>
            </div>

            <div className="relative">
              <Input
                type={showPasswords ? 'text' : 'password'}
                placeholder="At least 6 characters"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="pr-10 font-mono text-xs"
              />
              <button
                type="button"
                onClick={() => setShowPasswords(!showPasswords)}
                className="absolute right-3 top-2.5 text-neutral-400 hover:text-neutral-700 transition-colors"
                title={showPasswords ? 'Hide password' : 'Show password'}
              >
                {showPasswords ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1">
              Confirm New Password
            </label>
            <Input
              type={showPasswords ? 'text' : 'password'}
              placeholder="Re-enter new password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="font-mono text-xs"
            />
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsPasswordModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={changePassword.isPending}
              icon={<Key className="w-3.5 h-3.5" />}
            >
              Update Password
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
