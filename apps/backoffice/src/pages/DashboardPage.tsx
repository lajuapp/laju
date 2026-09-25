import React from 'react';
import {
  Users,
  Smartphone,
  MessageSquare,
  Image as ImageIcon,
  Smile,
  ShieldAlert,
  ArrowUpRight,
  Activity,
  CheckCircle2,
  Clock,
} from 'lucide-react';
import { useDashboardStats } from '../hooks/useDashboardStats';
import { Badge } from '../components/ui/Badge';
import { NavLink } from 'react-router-dom';

export function DashboardPage() {
  const { data: stats, isLoading } = useDashboardStats();

  const metrics = [
    {
      title: 'Total Pengguna',
      value: stats?.overview.totalUsers ?? 0,
      subValue: `${stats?.overview.activeUsers ?? 0} aktif • ${stats?.overview.suspendedUsers ?? 0} terkunci`,
      icon: Users,
      color: 'text-blue-600 bg-blue-50',
      link: '/users',
    },
    {
      title: 'Armada Perangkat',
      value: stats?.overview.totalDevices ?? 0,
      subValue: 'Perangkat terhubung aman',
      icon: Smartphone,
      color: 'text-emerald-600 bg-emerald-50',
      link: '/devices',
    },
    {
      title: 'Total Obrolan & Grup',
      value: stats?.overview.totalConversations ?? 0,
      subValue: `${stats?.overview.totalGroups ?? 0} grup • ${stats?.overview.totalMessages ?? 0} pesan`,
      icon: MessageSquare,
      color: 'text-violet-600 bg-violet-50',
      link: '/conversations',
    },
    {
      title: 'Aset Wallpaper & Stiker',
      value: (stats?.overview.totalWallpapers ?? 0) + (stats?.overview.totalStickerPacks ?? 0),
      subValue: `${stats?.overview.totalWallpapers ?? 0} wallpaper • ${stats?.overview.totalStickerPacks ?? 0} pack stiker`,
      icon: Smile,
      color: 'text-amber-600 bg-amber-50',
      link: '/stickers',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Top Welcome Title */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Ringkasan Sistem (Dashboard)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Status operasional, metrik ekosistem, dan jejak aktivitas administrasi terkini
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Badge variant="success" size="md">
            <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
            Semua Layanan Berjalan Normal
          </Badge>
        </div>
      </div>

      {/* 4 Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map((m, idx) => {
          const Icon = m.icon;
          return (
            <NavLink
              key={idx}
              to={m.link}
              className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:border-neutral-300 transition-all hover:shadow-sm group flex flex-col justify-between"
            >
              <div className="flex items-center justify-between mb-3">
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${m.color}`}>
                  <Icon className="w-4 h-4" />
                </div>
                <ArrowUpRight className="w-4 h-4 text-neutral-300 group-hover:text-neutral-700 transition-colors" />
              </div>

              <div>
                <p className="text-xs font-semibold text-neutral-500">{m.title}</p>
                <div className="text-2xl font-black text-neutral-900 mt-1 tracking-tight">
                  {isLoading ? '...' : m.value}
                </div>
                <p className="text-[11px] text-neutral-400 mt-1 font-medium">{m.subValue}</p>
              </div>
            </NavLink>
          );
        })}
      </div>

      {/* 2-Column Section: Recent Audit Log & Quick Tools */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Audit Activities (2 cols) */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs">
          <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-neutral-700" />
              <h2 className="text-sm font-bold text-neutral-900">Aktivitas Audit Terbaru</h2>
            </div>
            <NavLink
              to="/security"
              className="text-xs font-semibold text-neutral-500 hover:text-neutral-900 hover:underline"
            >
              Lihat Semua Log →
            </NavLink>
          </div>

          <div className="divide-y divide-neutral-100 mt-2">
            {stats?.recentAuditLogs && stats.recentAuditLogs.length > 0 ? (
              stats.recentAuditLogs.map((log) => (
                <div key={log.id} className="py-3 flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-[11px] font-bold text-neutral-800 bg-neutral-100 px-1.5 py-0.5 rounded">
                        {log.action}
                      </span>
                      <span className="text-xs text-neutral-500 font-medium">
                        di {log.resource}
                      </span>
                    </div>
                    <p className="text-xs text-neutral-600 mt-1 truncate">
                      {log.details}
                    </p>
                  </div>
                  <div className="flex items-center gap-1 text-[11px] text-neutral-400 font-mono whitespace-nowrap">
                    <Clock className="w-3 h-3" />
                    {new Date(log.createdAt).toLocaleTimeString('id-ID', {
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </div>
                </div>
              ))
            ) : (
              <div className="py-8 text-center text-xs text-neutral-400 font-medium">
                Belum ada aktivitas audit yang tercatat
              </div>
            )}
          </div>
        </div>

        {/* Quick Management Shortcuts */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs flex flex-col justify-between">
          <div>
            <h2 className="text-sm font-bold text-neutral-900 mb-3">Pintasan Cepat</h2>
            <p className="text-xs text-neutral-500 mb-4">
              Akses cepat fungsi administrasi paling sering digunakan
            </p>

            <div className="space-y-2">
              <NavLink
                to="/admins"
                className="flex items-center justify-between p-3 rounded-xl border border-neutral-100 bg-neutral-50/50 hover:bg-neutral-100/80 transition-colors"
              >
                <div className="flex items-center gap-2.5">
                  <Users className="w-4 h-4 text-neutral-700" />
                  <span className="text-xs font-bold text-neutral-900">Kelola Tim Admin</span>
                </div>
                <span className="text-[11px] text-neutral-400">Atur hak akses →</span>
              </NavLink>

              <NavLink
                to="/wallpapers"
                className="flex items-center justify-between p-3 rounded-xl border border-neutral-100 bg-neutral-50/50 hover:bg-neutral-100/80 transition-colors"
              >
                <div className="flex items-center gap-2.5">
                  <ImageIcon className="w-4 h-4 text-neutral-700" />
                  <span className="text-xs font-bold text-neutral-900">Upload Wallpaper</span>
                </div>
                <span className="text-[11px] text-neutral-400">Tambah baru →</span>
              </NavLink>

              <NavLink
                to="/stickers"
                className="flex items-center justify-between p-3 rounded-xl border border-neutral-100 bg-neutral-50/50 hover:bg-neutral-100/80 transition-colors"
              >
                <div className="flex items-center gap-2.5">
                  <Smile className="w-4 h-4 text-neutral-700" />
                  <span className="text-xs font-bold text-neutral-900">Kelola Sticker Pack</span>
                </div>
                <span className="text-[11px] text-neutral-400">Upload stiker →</span>
              </NavLink>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-neutral-100 text-[11px] text-neutral-400">
            LAJU Secure Messenger Platform • Backoffice v0.1.0
          </div>
        </div>
      </div>
    </div>
  );
}
