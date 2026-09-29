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
  Radio,
  PhoneCall,
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
      title: 'Perangkat',
      value: stats?.overview.totalDevices ?? 0,
      subValue: 'Perangkat terhubung aktif',
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
      link: '/devices',
    },
    {
      title: 'Konten Wallpaper & Stiker',
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

      {/* Realtime Statistics: Device Online & Offline */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Online Devices Card (Brand Mint) */}
        <div className="bg-gradient-to-r from-brand-500/10 via-brand-500/5 to-transparent bg-white rounded-2xl border border-brand-200/90 p-5 shadow-xs hover:shadow-md hover:border-brand-300 transition-all duration-200 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-brand-50 text-brand-600 border border-brand-200/90 flex items-center justify-center flex-shrink-0 shadow-2xs">
              <Radio className="w-6 h-6 animate-pulse" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-brand-800 uppercase tracking-wider">
                  Perangkat Online
                </span>
                <span className="w-2 h-2 rounded-full bg-brand-500 animate-ping" />
              </div>
              <div className="text-3xl font-black text-brand-950 mt-0.5 tracking-tight flex items-baseline gap-2">
                {isLoading ? '...' : (stats?.overview.onlineDevices ?? stats?.overview.onlineUsers ?? 0)}
                <span className="text-xs font-semibold text-brand-600">aktif sekarang</span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Perangkat terhubung aktif dalam 3-5 menit terakhir
              </p>
            </div>
          </div>
          <NavLink
            to="/devices"
            className="text-xs font-bold text-brand-700 hover:text-brand-800 bg-brand-50 px-3 py-1.5 rounded-xl border border-brand-200 hover:bg-brand-100/70 transition-all flex items-center gap-1 shadow-2xs"
          >
            Lihat Online
            <ArrowUpRight className="w-3.5 h-3.5" />
          </NavLink>
        </div>

        {/* Offline Devices Card (Neutral) */}
        <div className="bg-gradient-to-r from-neutral-500/10 via-neutral-500/5 to-transparent bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:shadow-md transition-all duration-200 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-neutral-100 text-neutral-500 border border-neutral-200/80 flex items-center justify-center flex-shrink-0 shadow-2xs">
              <Smartphone className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-600 uppercase tracking-wider">
                  Perangkat Offline
                </span>
                <span className="w-2 h-2 rounded-full bg-neutral-400" />
              </div>
              <div className="text-3xl font-black text-neutral-800 mt-0.5 tracking-tight flex items-baseline gap-2">
                {isLoading ? '...' : (stats?.overview.offlineDevices ?? Math.max(0, (stats?.overview.totalDevices ?? 0) - (stats?.overview.onlineDevices ?? stats?.overview.onlineUsers ?? 0)))}
                <span className="text-xs font-semibold text-neutral-500">tidak aktif</span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Perangkat terdaftar yang sedang tidak terhubung atau di luar jaringan
              </p>
            </div>
          </div>
          <NavLink
            to="/devices"
            className="text-xs font-bold text-neutral-700 hover:text-neutral-900 bg-neutral-100 px-3 py-1.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-200/60 transition-all flex items-center gap-1 shadow-2xs"
          >
            Kelola Perangkat
            <ArrowUpRight className="w-3.5 h-3.5" />
          </NavLink>
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
              className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:border-brand-300 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 group flex flex-col justify-between"
            >
              <div className="flex items-center justify-between mb-3">
                <div className={`w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs ${m.color}`}>
                  <Icon className="w-4 h-4" />
                </div>
                <ArrowUpRight className="w-4 h-4 text-neutral-300 group-hover:text-brand-600 transition-colors" />
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
