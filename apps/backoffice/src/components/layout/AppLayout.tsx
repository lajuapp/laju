import React from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Smartphone,
  Image as ImageIcon,
  Smile,
  ShieldAlert,
  MessageSquare,
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
        { label: 'Audit Obrolan', to: '/conversations', icon: MessageSquare },
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
    <div className="min-h-screen bg-[#F8FAFC] flex text-neutral-900 font-sans selection:bg-neutral-200">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-neutral-200/80 flex flex-col fixed inset-y-0 z-30 shadow-[1px_0_4px_rgba(0,0,0,0.02)]">
        {/* Brand Header */}
        <div className="h-16 flex items-center gap-3 px-6 border-b border-neutral-100">
          <div className="w-8 h-8 rounded-xl bg-neutral-900 text-white flex items-center justify-center font-black text-sm tracking-tight shadow-sm">
            LJ
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-extrabold text-sm tracking-tight text-neutral-900">
                LAJU
              </span>
              <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200/50">
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
                        'flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all group',
                        isActive
                          ? 'bg-neutral-900 text-white shadow-sm'
                          : 'text-neutral-600 hover:text-neutral-900 hover:bg-neutral-100/80'
                      )
                    }
                  >
                    {({ isActive }) => (
                      <>
                        <Icon
                          className={clsx(
                            'w-4 h-4 transition-colors',
                            isActive ? 'text-white' : 'text-neutral-400 group-hover:text-neutral-700'
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
        <div className="p-3 border-t border-neutral-100 bg-neutral-50/50">
          <div className="flex items-center justify-between p-2 rounded-xl bg-white border border-neutral-200/70 shadow-xs">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-8 h-8 rounded-lg bg-neutral-100 text-neutral-800 border border-neutral-200/80 flex items-center justify-center font-bold text-xs uppercase flex-shrink-0">
                {admin?.name?.substring(0, 2) || 'AD'}
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
        <header className="h-16 bg-white/80 backdrop-blur-md border-b border-neutral-200/80 sticky top-0 z-20 flex items-center justify-between px-8">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-neutral-600">
              Sistem Backoffice
            </span>
          </div>

          <div className="flex items-center gap-4">
            <span className="text-xs text-neutral-400 font-mono">
              LAJU Enterprise Console v1.0
            </span>
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
