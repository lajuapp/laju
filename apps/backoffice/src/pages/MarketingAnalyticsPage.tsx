import React, { useState } from 'react';
import {
  Download,
  Users,
  Smartphone,
  TrendingUp,
  Percent,
  Compass,
  Layers,
  ArrowUpRight,
  Filter,
  CheckCircle2,
  Calendar,
  Sparkles,
  BarChart3,
  Globe,
  MonitorSmartphone,
  RefreshCw
} from 'lucide-react';
import { useMarketingStats } from '../hooks/useMarketingStats';
import { Badge } from '../components/ui/Badge';

export function MarketingAnalyticsPage() {
  const { data: stats, isLoading, refetch, isFetching } = useMarketingStats();
  const [activeTab, setActiveTab] = useState<'DOWNLOADS' | 'REGISTRATIONS'>('DOWNLOADS');

  const overview = stats?.overview;
  const trend = stats?.trend || [];
  const distributions = stats?.distributions;

  const maxVal = Math.max(
    ...trend.map((d) => (activeTab === 'DOWNLOADS' ? d.downloads : d.registrations)),
    5
  );

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900 flex items-center gap-2">
            <BarChart3 className="w-5 h-5 text-brand-600" />
            Statistik Pemasaran & Perilaku Pengguna
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Pantau performa unduhan APK dari landing page, corong konversi instalasi, serta perilaku & distribusi perangkat pengguna aktif.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-white text-neutral-700 border border-neutral-200 rounded-xl text-xs font-semibold shadow-2xs hover:bg-neutral-50 transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isFetching ? 'animate-spin text-brand-600' : ''}`} />
            Perbarui Data
          </button>
        </div>
      </div>

      {/* Top Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Total Unduhan */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-brand-600 bg-brand-50">
                <Download className="w-4 h-4" />
              </div>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-brand-50 text-brand-700 border border-brand-200">
                +{overview?.downloadsToday ?? 0} hari ini
              </span>
            </div>
            <p className="text-xs font-semibold text-neutral-500">Total Unduhan APK</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (overview?.totalDownloads ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">kali</span>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>{overview?.downloadsThisWeek ?? 0} minggu ini</span>
            <span>•</span>
            <span>{overview?.downloadsThisMonth ?? 0} bulan ini</span>
          </div>
        </div>

        {/* Card 2: Pengguna Terdaftar */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-blue-600 bg-blue-50">
                <Users className="w-4 h-4" />
              </div>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                +{overview?.newUsersToday ?? 0} hari ini
              </span>
            </div>
            <p className="text-xs font-semibold text-neutral-500">Pengguna Terdaftar</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (overview?.totalUsers ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">akun</span>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>{overview?.newUsersThisWeek ?? 0} minggu ini</span>
            <span>•</span>
            <span>{overview?.newUsersThisMonth ?? 0} bulan ini</span>
          </div>
        </div>

        {/* Card 3: Tingkat Konversi (Corong) */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-emerald-600 bg-emerald-50">
                <TrendingUp className="w-4 h-4" />
              </div>
              <span className="text-[11px] font-mono font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md">
                Corong Instal
              </span>
            </div>
            <p className="text-xs font-semibold text-neutral-500">Konversi Download ke Akun</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : `${overview?.conversionRatePercent ?? 0}%`}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">rasio</span>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>Target Ideal: &gt;50%</span>
            <span>•</span>
            <span className="text-emerald-600 font-medium">Kualitas Trafik Baik</span>
          </div>
        </div>

        {/* Card 4: Retensi Pengguna Aktif (DAU) */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-violet-600 bg-violet-50">
                <MonitorSmartphone className="w-4 h-4" />
              </div>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-violet-50 text-violet-700 border border-violet-200">
                {overview?.activeRetentionPercent ?? 0}% aktif
              </span>
            </div>
            <p className="text-xs font-semibold text-neutral-500">Pengguna Aktif Harian (DAU)</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (overview?.dauCount ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">user/24j</span>
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>Retensi Pengguna Baru</span>
            <span>•</span>
            <span>Terkoneksi Realtime</span>
          </div>
        </div>
      </div>

      {/* Main Chart Section: Tren 14 Hari */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
          <div>
            <h2 className="text-sm font-bold text-neutral-900 flex items-center gap-2">
              Tren Unduhan vs Pendaftaran (14 Hari Terakhir)
            </h2>
            <p className="text-xs text-neutral-500 mt-0.5">
              Perbandingan harian antara pengunjung yang mengunduh APK dan yang berhasil mendaftarkan akun.
            </p>
          </div>

          <div className="flex items-center bg-neutral-100/80 p-1 rounded-xl">
            <button
              onClick={() => setActiveTab('DOWNLOADS')}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
                activeTab === 'DOWNLOADS'
                  ? 'bg-white text-neutral-900 shadow-2xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              Unduhan APK ({trend.reduce((acc, curr) => acc + curr.downloads, 0)})
            </button>
            <button
              onClick={() => setActiveTab('REGISTRATIONS')}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
                activeTab === 'REGISTRATIONS'
                  ? 'bg-white text-neutral-900 shadow-2xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              Registrasi Akun ({trend.reduce((acc, curr) => acc + curr.registrations, 0)})
            </button>
          </div>
        </div>

        {/* SVG Bar Chart */}
        <div className="h-64 flex items-end gap-2 pt-6 pb-2 px-2 border-b border-neutral-100">
          {trend.map((item, idx) => {
            const currentVal = activeTab === 'DOWNLOADS' ? item.downloads : item.registrations;
            const heightPercent = Math.max(6, Math.round((currentVal / maxVal) * 100));

            return (
              <div key={idx} className="flex-1 flex flex-col items-center h-full justify-end group relative">
                {/* Tooltip */}
                <div className="absolute -top-10 opacity-0 group-hover:opacity-100 transition-opacity bg-neutral-900 text-white text-[10px] py-1 px-2 rounded pointer-events-none whitespace-nowrap z-20 shadow-md">
                  <div className="font-bold">{item.date}</div>
                  <div>
                    {activeTab === 'DOWNLOADS' ? 'Unduhan' : 'Registrasi'}: {currentVal}
                  </div>
                </div>

                {/* Value on top of bar if > 0 */}
                {currentVal > 0 && (
                  <span className="text-[10px] font-bold text-neutral-600 mb-1">
                    {currentVal}
                  </span>
                )}

                {/* Bar */}
                <div
                  style={{ height: `${heightPercent}%` }}
                  className={`w-full max-w-[36px] rounded-t-lg transition-all duration-300 ${
                    activeTab === 'DOWNLOADS'
                      ? 'bg-brand-500 group-hover:bg-brand-600'
                      : 'bg-blue-500 group-hover:bg-blue-600'
                  }`}
                />

                {/* X-axis Label */}
                <div className="text-[10px] font-medium text-neutral-400 mt-2 truncate w-full text-center">
                  {item.label}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Behavioral & Distribution Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* 1. Model Ponsel Terbanyak */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xs font-bold text-neutral-900 uppercase tracking-wider flex items-center gap-2">
              <Smartphone className="w-4 h-4 text-brand-600" />
              Model Ponsel Pengguna
            </h3>
            <span className="text-[10px] text-neutral-400">Top 10</span>
          </div>

          <div className="space-y-3">
            {(distributions?.deviceModels || []).length === 0 ? (
              <p className="text-xs text-neutral-400 py-4 text-center">Belum ada data perangkat</p>
            ) : (
              (distributions?.deviceModels || []).map((m, i) => {
                const total = (distributions?.deviceModels || []).reduce((a, b) => a + b.count, 0);
                const percent = total > 0 ? Math.round((m.count / total) * 100) : 0;
                return (
                  <div key={i} className="space-y-1">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-neutral-700 truncate max-w-[180px]">{m.model}</span>
                      <span className="text-neutral-500 text-[11px] font-mono">{m.count} ({percent}%)</span>
                    </div>
                    <div className="w-full bg-neutral-100 rounded-full h-1.5 overflow-hidden">
                      <div
                        className="bg-brand-500 h-1.5 rounded-full"
                        style={{ width: `${Math.max(4, percent)}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* 2. Versi Android & OS */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xs font-bold text-neutral-900 uppercase tracking-wider flex items-center gap-2">
              <Layers className="w-4 h-4 text-blue-600" />
              Versi OS Android Terpasang
            </h3>
            <span className="text-[10px] text-neutral-400">Distribusi</span>
          </div>

          <div className="space-y-3">
            {(distributions?.osVersions || []).length === 0 ? (
              <p className="text-xs text-neutral-400 py-4 text-center">Belum ada data OS</p>
            ) : (
              (distributions?.osVersions || []).map((o, i) => {
                const total = (distributions?.osVersions || []).reduce((a, b) => a + b.count, 0);
                const percent = total > 0 ? Math.round((o.count / total) * 100) : 0;
                return (
                  <div key={i} className="space-y-1">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-neutral-700">{o.os}</span>
                      <span className="text-neutral-500 text-[11px] font-mono">{o.count} ({percent}%)</span>
                    </div>
                    <div className="w-full bg-neutral-100 rounded-full h-1.5 overflow-hidden">
                      <div
                        className="bg-blue-500 h-1.5 rounded-full"
                        style={{ width: `${Math.max(4, percent)}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* 3. Saluran Sumber Unduhan (Marketing Channels) */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xs font-bold text-neutral-900 uppercase tracking-wider flex items-center gap-2">
              <Globe className="w-4 h-4 text-emerald-600" />
              Saluran Sumber Unduhan
            </h3>
            <span className="text-[10px] text-neutral-400">Referrer</span>
          </div>

          <div className="space-y-3">
            {(distributions?.sources || []).length === 0 ? (
              <p className="text-xs text-neutral-400 py-4 text-center">Belum ada data sumber</p>
            ) : (
              (distributions?.sources || []).map((s, i) => {
                const total = (distributions?.sources || []).reduce((a, b) => a + b.count, 0);
                const percent = total > 0 ? Math.round((s.count / total) * 100) : 0;
                return (
                  <div key={i} className="space-y-1">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-semibold text-neutral-700">{s.source}</span>
                      <span className="text-neutral-500 text-[11px] font-mono">{s.count} ({percent}%)</span>
                    </div>
                    <div className="w-full bg-neutral-100 rounded-full h-1.5 overflow-hidden">
                      <div
                        className="bg-emerald-500 h-1.5 rounded-full"
                        style={{ width: `${Math.max(4, percent)}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
