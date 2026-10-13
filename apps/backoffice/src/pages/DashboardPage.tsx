import React, { useState } from 'react';
import {
  Users,
  Smartphone,
  MessageSquare,
  ShieldAlert,
  ArrowUpRight,
  Activity,
  Clock,
  Radio,
  TrendingUp,
  TrendingDown,
  UserPlus,
  Zap,
  Layers,
  AlertTriangle,
  ChevronRight,
  ShieldCheck,
  Download,
} from 'lucide-react';

import { useDashboardStats } from '../hooks/useDashboardStats';
import { NavLink } from 'react-router-dom';

export function DashboardPage() {
  const { data: stats, isLoading } = useDashboardStats();
  const [activeChartTab, setActiveChartTab] = useState<'REGISTRATIONS' | 'MESSAGES'>('REGISTRATIONS');

  const growth = stats?.growth;
  const overview = stats?.overview;
  const trustAndSafety = stats?.trustAndSafety;
  const dailyRegs = stats?.timeSeries?.dailyRegistrations || [];
  const dailyMsgs = stats?.timeSeries?.dailyMessages || [];

  // Max value for scaling SVG chart
  const activeSeries = activeChartTab === 'REGISTRATIONS' ? dailyRegs : dailyMsgs;
  const maxVal = Math.max(...activeSeries.map((d) => d.count), 5);

  return (
    <div className="space-y-6">
      {/* Top Welcome Title & Live Indicator */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900 flex items-center gap-2">
            System Overview & Network Telemetry
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Real-time operational status, user adoption growth, network traffic metrics, and safety oversight.
          </p>
        </div>

        <div className="flex items-center gap-3">
          {/* Status Live Indicator */}
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-800 border border-emerald-200/80 rounded-xl text-xs font-semibold shadow-2xs">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            System Healthy
          </div>
        </div>
      </div>

      {/* Alert Banner if Pending Reports exist */}
      {(trustAndSafety?.pendingReportsCount ?? 0) > 0 && (
        <div className="bg-gradient-to-r from-rose-500/10 via-rose-500/5 to-transparent bg-white rounded-2xl border border-rose-200 p-4 shadow-xs flex items-center justify-between gap-4 animate-in fade-in duration-200">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center flex-shrink-0">
              <ShieldAlert className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xs font-bold text-rose-900 flex items-center gap-2">
                Trust & Moderation Notice
                <span className="px-2 py-0.2 rounded-full text-[10px] font-extrabold bg-rose-600 text-white">
                  {trustAndSafety?.pendingReportsCount} Pending Reports
                </span>
              </div>
              <p className="text-[11px] text-rose-700 mt-0.5">
                Spam or misconduct reports have been submitted and await moderation review and Trust Score evaluation.
              </p>
            </div>
          </div>
          <NavLink
            to="/reports"
            className="text-xs font-bold text-rose-700 hover:text-rose-800 bg-rose-100 hover:bg-rose-200/80 px-3.5 py-2 rounded-xl transition-all flex items-center gap-1 shadow-2xs whitespace-nowrap"
          >
            Review Reports
            <ChevronRight className="w-3.5 h-3.5" />
          </NavLink>
        </div>
      )}

      {/* Realtime Statistics: Device Online & Offline */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Online Devices Card */}
        <div className="bg-gradient-to-r from-brand-500/10 via-brand-500/5 to-transparent bg-white rounded-2xl border border-brand-200/90 p-5 shadow-xs hover:shadow-md hover:border-brand-300 transition-all duration-200 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-brand-50 text-brand-600 border border-brand-200/90 flex items-center justify-center flex-shrink-0 shadow-2xs">
              <Radio className="w-6 h-6 animate-pulse" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-brand-800 uppercase tracking-wider">
                  Devices Online
                </span>
                <span className="w-2 h-2 rounded-full bg-brand-500 animate-ping" />
              </div>
              <div className="text-3xl font-black text-brand-950 mt-0.5 tracking-tight flex items-baseline gap-2">
                {isLoading ? '...' : (overview?.onlineDevices ?? overview?.onlineUsers ?? 0)}
                <span className="text-xs font-semibold text-brand-600">active now</span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Client devices connected in the last 3-5 minutes
              </p>
            </div>
          </div>
          <NavLink
            to="/devices"
            className="text-xs font-bold text-brand-700 hover:text-brand-800 bg-brand-50 px-3 py-1.5 rounded-xl border border-brand-200 hover:bg-brand-100/70 transition-all flex items-center gap-1 shadow-2xs"
          >
            View Online
            <ArrowUpRight className="w-3.5 h-3.5" />
          </NavLink>
        </div>

        {/* Offline Devices Card */}
        <div className="bg-gradient-to-r from-neutral-500/10 via-neutral-500/5 to-transparent bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:shadow-md transition-all duration-200 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-neutral-100 text-neutral-500 border border-neutral-200/80 flex items-center justify-center flex-shrink-0 shadow-2xs">
              <Smartphone className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-neutral-600 uppercase tracking-wider">
                  Devices Offline
                </span>
                <span className="w-2 h-2 rounded-full bg-neutral-400" />
              </div>
              <div className="text-3xl font-black text-neutral-800 mt-0.5 tracking-tight flex items-baseline gap-2">
                {isLoading ? '...' : (overview?.offlineDevices ?? Math.max(0, (overview?.totalDevices ?? 0) - (overview?.onlineDevices ?? 0)))}
                <span className="text-xs font-semibold text-neutral-500">inactive</span>
              </div>
              <p className="text-[11px] text-neutral-500 mt-0.5">
                Registered devices currently unreachable or disconnected
              </p>
            </div>
          </div>
          <NavLink
            to="/devices"
            className="text-xs font-bold text-neutral-700 hover:text-neutral-900 bg-neutral-100 px-3 py-1.5 rounded-xl border border-neutral-200/80 hover:bg-neutral-200/60 transition-all flex items-center gap-1 shadow-2xs"
          >
            Manage Devices
            <ArrowUpRight className="w-3.5 h-3.5" />
          </NavLink>
        </div>
      </div>

      {/* Core Growth, Metrics & Activity Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
        {/* 0. Total Downloads */}
        <NavLink
          to="/service-stats"
          className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:border-brand-400 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 group flex flex-col justify-between"
        >
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-brand-600 bg-brand-50">
                <Download className="w-4 h-4" />
              </div>
              <span className="inline-flex items-center gap-0.5 text-[11px] font-bold px-2 py-0.5 rounded-full bg-brand-50 text-brand-700 border border-brand-200">
                +{overview?.downloadsToday ?? 0} today
              </span>
            </div>

            <p className="text-xs font-semibold text-neutral-500">Total Client Downloads</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (overview?.totalDownloads ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">times</span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span className="text-brand-600 font-semibold group-hover:underline flex items-center gap-1">
              View Service Statistics
              <ArrowUpRight className="w-3 h-3" />
            </span>
          </div>
        </NavLink>

        {/* 1. New Users */}
        <NavLink
          to="/users"
          className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:border-brand-300 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 group flex flex-col justify-between"
        >
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-blue-600 bg-blue-50">
                <UserPlus className="w-4 h-4" />
              </div>
              {growth && (
                <span
                  className={`inline-flex items-center gap-0.5 text-[11px] font-bold px-2 py-0.5 rounded-full ${
                    growth.dailyGrowthPercent >= 0
                      ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                      : 'bg-rose-50 text-rose-700 border border-rose-200'
                  }`}
                >
                  {growth.dailyGrowthPercent >= 0 ? (
                    <TrendingUp className="w-3 h-3" />
                  ) : (
                    <TrendingDown className="w-3 h-3" />
                  )}
                  {growth.dailyGrowthPercent >= 0 ? `+${growth.dailyGrowthPercent}%` : `${growth.dailyGrowthPercent}%`}
                </span>
              )}
            </div>

            <p className="text-xs font-semibold text-neutral-500">New Users Today</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (growth?.newUsersToday ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">accounts</span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>{growth?.newUsersThisWeek ?? 0} this week</span>
            <span>•</span>
            <span>{growth?.newUsersThisMonth ?? 0} this month</span>
          </div>
        </NavLink>

        {/* 2. DAU Stickiness */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-emerald-600 bg-emerald-50">
                <Zap className="w-4 h-4" />
              </div>
              <span className="inline-flex items-center gap-0.5 text-[11px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                Ratio: {growth?.stickinessRatio ?? 0}%
              </span>
            </div>

            <p className="text-xs font-semibold text-neutral-500">Daily Active Users (DAU)</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (growth?.dau ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">users/24h</span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>{growth?.wau ?? 0} WAU (7 days)</span>
            <span>•</span>
            <span>{growth?.mau ?? 0} MAU (30 days)</span>
          </div>
        </div>

        {/* 3. Messages & Chat Traffic */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-violet-600 bg-violet-50">
                <MessageSquare className="w-4 h-4" />
              </div>
              <span className="text-[11px] font-mono font-bold text-violet-700 bg-violet-50 px-2 py-0.5 rounded-md">
                E2EE Chat
              </span>
            </div>

            <p className="text-xs font-semibold text-neutral-500">Messages Sent Today</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (overview?.messagesToday ?? 0)}
              <span className="text-xs font-semibold text-neutral-400 ml-1.5">messages</span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span>{overview?.totalMessages ?? 0} total messages</span>
            <span>•</span>
            <span>{overview?.totalCallsToday ?? 0} calls today</span>
          </div>
        </div>

        {/* 4. Trust & Safety Score */}
        <NavLink
          to="/reports"
          className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs hover:border-amber-300 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 group flex flex-col justify-between"
        >
          <div>
            <div className="flex items-center justify-between mb-3">
              <div className="w-9 h-9 rounded-xl flex items-center justify-center shadow-2xs text-amber-600 bg-amber-50">
                <ShieldCheck className="w-4 h-4" />
              </div>
              {(trustAndSafety?.pendingReportsCount ?? 0) > 0 ? (
                <span className="inline-flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200">
                  <AlertTriangle className="w-3 h-3" />
                  {trustAndSafety?.pendingReportsCount} Reports
                </span>
              ) : (
                <span className="inline-flex items-center gap-1 text-[11px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                  Secure
                </span>
              )}
            </div>

            <p className="text-xs font-semibold text-neutral-500">User Trust Health</p>
            <div className="text-3xl font-black text-neutral-900 mt-1 tracking-tight">
              {isLoading ? '...' : (trustAndSafety?.healthyUsersCount ?? overview?.activeUsers ?? 0)}
              <span className="text-xs font-semibold text-emerald-600 ml-1.5">healthy</span>
            </div>
          </div>

          <div className="mt-4 pt-3 border-t border-neutral-100 flex items-center justify-between text-[11px] text-neutral-500">
            <span className="text-rose-600 font-semibold">{trustAndSafety?.atRiskUsersCount ?? 0} at-risk</span>
            <span>•</span>
            <span>{overview?.suspendedUsers ?? 0} suspended</span>
          </div>
        </NavLink>
      </div>

      {/* Interactive Growth & Traffic Trend Chart Section */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-5 border-b border-neutral-100">
          <div>
            <h2 className="text-sm font-bold text-neutral-900 flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-brand-600" />
              {activeChartTab === 'REGISTRATIONS'
                ? 'User Registrations Growth Trend (Last 14 Days)'
                : 'Message Volume Trend (Last 7 Days)'}
            </h2>
            <p className="text-xs text-neutral-500 mt-0.5">
              Daily time-series telemetry of network adoption and traffic activity.
            </p>
          </div>

          {/* Chart View Switcher */}
          <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
            <button
              onClick={() => setActiveChartTab('REGISTRATIONS')}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
                activeChartTab === 'REGISTRATIONS'
                  ? 'bg-white text-neutral-900 shadow-xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              Registrations
            </button>
            <button
              onClick={() => setActiveChartTab('MESSAGES')}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
                activeChartTab === 'MESSAGES'
                  ? 'bg-white text-neutral-900 shadow-xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              Message Volume
            </button>
          </div>
        </div>

        {/* Scalable Vector SVG Bar Chart */}
        <div className="pt-6">
          {activeSeries.length === 0 ? (
            <div className="py-16 text-center text-xs text-neutral-400">
              No registration records found for this period
            </div>
          ) : (
            <div className="space-y-2">
              {/* Bars container */}
              <div className="h-48 flex items-end gap-2 sm:gap-3 pt-6 pb-2 px-2 border-b border-neutral-100">
                {activeSeries.map((item, idx) => {
                  const heightPercent = maxVal > 0 ? Math.max(6, Math.round((item.count / maxVal) * 100)) : 6;
                  const isCurrentDay = idx === activeSeries.length - 1;
                  return (
                    <div
                      key={item.date}
                      className="flex-1 flex flex-col items-center justify-end h-full group relative"
                    >
                      {/* Tooltip on hover */}
                      <div className="opacity-0 group-hover:opacity-100 pointer-events-none absolute -top-8 transition-opacity duration-150 z-20 bg-neutral-900 text-white text-[10px] font-bold px-2 py-0.5 rounded shadow-md whitespace-nowrap">
                        {item.count} {activeChartTab === 'REGISTRATIONS' ? 'new accounts' : 'messages'}
                      </div>

                      {/* Bar Value above bar */}
                      <span className="text-[10px] font-bold text-neutral-400 group-hover:text-neutral-900 transition-colors mb-1">
                        {item.count}
                      </span>

                      {/* Bar Pillar */}
                      <div
                        style={{ height: `${heightPercent}%` }}
                        className={`w-full max-w-[36px] rounded-t-lg transition-all duration-300 ${
                          isCurrentDay
                            ? 'bg-brand-500 group-hover:bg-brand-600 shadow-xs shadow-brand-500/20'
                            : 'bg-neutral-200 group-hover:bg-neutral-300'
                        }`}
                      />
                    </div>
                  );
                })}
              </div>

              {/* Date labels below bars */}
              <div className="flex items-center gap-2 sm:gap-3 px-2 pt-1 text-[10px] font-medium text-neutral-400 justify-between">
                {activeSeries.map((item, idx) => (
                  <div
                    key={item.date}
                    className={`flex-1 text-center truncate ${
                      idx === activeSeries.length - 1 ? 'font-bold text-brand-700' : ''
                    }`}
                  >
                    {item.label}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* 2-Column Section: Ecosystem Breakdown & Audit Logs */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column: Platform & Ecosystem Breakdown */}
        <div className="space-y-6">
          {/* Platform Distribution Card */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs">
            <h3 className="text-xs font-bold uppercase tracking-wider text-neutral-500 mb-4 flex items-center justify-between">
              <span>Client Platform Distribution</span>
              <Smartphone className="w-3.5 h-3.5" />
            </h3>

            <div className="space-y-3">
              {stats?.distributions?.platforms && stats.distributions.platforms.length > 0 ? (
                stats.distributions.platforms.map((p) => {
                  const total = overview?.totalDevices || 1;
                  const pct = Math.round((p.count / total) * 100);
                  return (
                    <div key={p.platform} className="space-y-1">
                      <div className="flex items-center justify-between text-xs font-bold text-neutral-800">
                        <span>{p.platform}</span>
                        <span className="font-mono text-neutral-500">{p.count} units ({pct}%)</span>
                      </div>
                      <div className="h-2 rounded-full bg-neutral-100 overflow-hidden">
                        <div
                          style={{ width: `${pct}%` }}
                          className={`h-full rounded-full ${
                            p.platform === 'ANDROID'
                              ? 'bg-emerald-500'
                              : p.platform === 'IOS'
                              ? 'bg-blue-500'
                              : 'bg-neutral-500'
                          }`}
                        />
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="py-4 text-center text-xs text-neutral-400">
                  No device data recorded
                </div>
              )}
            </div>
          </div>

          {/* Top Mobile App Versions Card */}
          <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xs font-bold uppercase tracking-wider text-neutral-500">
                Client App Adoption
              </h3>
              <NavLink
                to="/app-version"
                className="text-[11px] font-bold text-brand-700 hover:underline"
              >
                Configure →
              </NavLink>
            </div>

            <div className="space-y-2.5">
              {stats?.distributions?.appVersions && stats.distributions.appVersions.length > 0 ? (
                stats.distributions.appVersions.map((v) => (
                  <div key={v.version} className="flex items-center justify-between p-2.5 rounded-xl bg-neutral-50 text-xs">
                    <span className="font-mono font-bold text-neutral-800">{v.version}</span>
                    <span className="text-neutral-500 font-medium">{v.count} active devices</span>
                  </div>
                ))
              ) : (
                <div className="py-4 text-center text-xs text-neutral-400">
                  No app versions registered
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Recent Audit Activities */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
              <div className="flex items-center gap-2">
                <Activity className="w-4 h-4 text-neutral-700" />
                <h2 className="text-sm font-bold text-neutral-900">Recent Audit Activities</h2>
              </div>
              <NavLink
                to="/security"
                className="text-xs font-semibold text-neutral-500 hover:text-neutral-900 hover:underline"
              >
                View Full Audit Logs →
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
                          on {log.resource}
                        </span>
                      </div>
                      <p className="text-xs text-neutral-600 mt-1 truncate">
                        {log.details}
                      </p>
                    </div>
                    <div className="flex items-center gap-1 text-[11px] text-neutral-400 font-mono whitespace-nowrap">
                      <Clock className="w-3 h-3" />
                      {new Date(log.createdAt).toLocaleTimeString('en-US', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </div>
                  </div>
                ))
              ) : (
                <div className="py-8 text-center text-xs text-neutral-400 font-medium">
                  No recent audit logs recorded
                </div>
              )}
            </div>
          </div>

          {/* Quick Shortcuts */}
          <div className="mt-6 pt-5 border-t border-neutral-100">
            <h4 className="text-xs font-bold uppercase tracking-wider text-neutral-400 mb-3">
              Operational Shortcuts
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 text-xs">
              <NavLink
                to="/reports"
                className="p-3 rounded-xl border border-neutral-200/70 hover:bg-neutral-50 transition-colors flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <ShieldAlert className="w-3.5 h-3.5 text-rose-600" />
                  <span className="font-bold text-neutral-800">Reports Center</span>
                </div>
                <ArrowUpRight className="w-3 h-3 text-neutral-400" />
              </NavLink>

              <NavLink
                to="/app-version"
                className="p-3 rounded-xl border border-neutral-200/70 hover:bg-neutral-50 transition-colors flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Layers className="w-3.5 h-3.5 text-brand-600" />
                  <span className="font-bold text-neutral-800">Versions & Releases</span>
                </div>
                <ArrowUpRight className="w-3 h-3 text-neutral-400" />
              </NavLink>

              <NavLink
                to="/admins"
                className="p-3 rounded-xl border border-neutral-200/70 hover:bg-neutral-50 transition-colors flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Users className="w-3.5 h-3.5 text-blue-600" />
                  <span className="font-bold text-neutral-800">Admin Team</span>
                </div>
                <ArrowUpRight className="w-3 h-3 text-neutral-400" />
              </NavLink>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
