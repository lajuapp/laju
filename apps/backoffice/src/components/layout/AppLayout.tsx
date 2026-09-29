import React from 'react';
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
  Megaphone,
  Settings2,
} from 'lucide-react';
import { useAdminMe, useLogout } from '../../hooks/useAdminAuth';
import { Badge } from '../ui/Badge';
import { clsx } from 'clsx';

export function AppLayout() {
  const navigate = useNavigate();
  const { data: admin, isLoading } = useAdminMe();
  const logout = useLogout();

  React.useEffect(() => {
    const token = localStorage.getItem('laju_admin_token');
    if (!token && !isLoading) {
      navigate('/login');
    }
  }, [navigate, isLoading]);

  const navGroups = [
    {
      group: 'Utama',
      items: [
        { label: 'Dashboard', to: '/', icon: LayoutDashboard },
      ],
    },
    {
      group: 'Konten',
      items: [
        { label: 'Wallpaper Obrolan', to: '/wallpapers', icon: ImageIcon },
        { label: 'Stiker & Packs', to: '/stickers', icon: Smile },
        { label: 'Status Resmi LAJU', to: '/announcements', icon: Sparkles },
      ],
    },
    {
      group: 'Pengaturan Sistem',
      items: [
        { label: 'Versi Aplikasi', to: '/app-version', icon: Settings2 },
      ],
    },
    {
      group: 'Kepatuhan & Keamanan',
      items: [
        { label: 'Log Aktivitas', to: '/security', icon: ShieldAlert },
      ],
    },
    {
      group: 'Akses & Pengguna',
      items: [
        { label: 'Tim Admin', to: '/admins', icon: ShieldCheck },
        { label: 'Direktori Pengguna', to: '/users', icon: Users },
        { label: 'Perangkat', to: '/devices', icon: Smartphone },
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
                        <span>{item.label}</span>
                      </>
                    )}
                  </NavLink>
                );
              })}
            </div>
          ))}
        </nav>

        {/* User Profile & Logout */}
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
            <button
              onClick={() => logout.mutate()}
              title="Logout"
              className="p-1.5 rounded-lg text-neutral-400 hover:text-rose-600 hover:bg-rose-50 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
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
              <span>Platform Node Aktif</span>
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
    </div>
  );
}
