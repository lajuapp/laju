import React from 'react';
import {
  X,
  Smartphone,
  MessageSquare,
  ShieldCheck,
  ShieldAlert,
  Calendar,
  Lock,
  Unlock,
  Radio,
  Clock,
  Globe,
  AlertTriangle,
  UserCheck,
} from 'lucide-react';
import { useUserDetails, useSuspendUser, useRestoreUser } from '../../hooks/useUsers';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';

interface UserDetailModalProps {
  userId: string | null;
  isOpen: boolean;
  onClose: () => void;
  onOpenSuspend?: (userId: string, username: string) => void;
  onOpenRestore?: (userId: string, username: string) => void;
}

export function UserDetailModal({
  userId,
  isOpen,
  onClose,
  onOpenSuspend,
  onOpenRestore,
}: UserDetailModalProps) {
  const { data: user, isLoading } = useUserDetails(userId || undefined);

  if (!isOpen || !userId) return null;

  const getTrustBadge = (score: number) => {
    if (score >= 80) {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
          <ShieldCheck className="w-3.5 h-3.5" />
          Trust Score: {score}/100 (Tinggi)
        </span>
      );
    }
    if (score >= 50) {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-50 text-amber-700 border border-amber-200">
          <AlertTriangle className="w-3.5 h-3.5" />
          Trust Score: {score}/100 (Sedang)
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-rose-50 text-rose-700 border border-rose-200">
        <ShieldAlert className="w-3.5 h-3.5" />
        Trust Score: {score}/100 (Kritis)
      </span>
    );
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-neutral-900/60 backdrop-blur-xs flex items-center justify-center p-4">
      <div className="bg-white rounded-3xl border border-neutral-200 shadow-2xl max-w-2xl w-full overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-neutral-100 bg-neutral-50/50">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-neutral-900 text-white flex items-center justify-center font-black text-sm uppercase shadow-xs">
              {user ? user.username.substring(0, 2) : '..'}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold text-neutral-900">
                  {user ? `@${user.username}` : 'Memuat data...'}
                </h3>
                {user && (
                  <Badge variant={user.status === 'ACTIVE' ? 'success' : 'error'}>
                    {user.status === 'ACTIVE' ? 'Aktif' : 'Terkunci'}
                  </Badge>
                )}
              </div>
              <p className="text-xs text-neutral-400 font-mono">
                User ID: {user?.id}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-neutral-400 hover:text-neutral-700 hover:bg-neutral-100 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-6 space-y-6 max-h-[80vh] overflow-y-auto">
          {isLoading ? (
            <div className="py-12 text-center text-xs text-neutral-400">
              Memuat profil detail pengguna...
            </div>
          ) : user ? (
            <>
              {/* Trust Score & Security Row */}
              <div className="flex flex-wrap items-center justify-between gap-3 p-4 rounded-2xl bg-neutral-50/80 border border-neutral-200/60">
                <div className="flex items-center gap-3">
                  {getTrustBadge(user.trustScore ?? 100)}
                  <span className="text-xs text-neutral-500">
                    2FA: <strong className="text-neutral-800">{user.twoFactorEnabled ? 'Aktif' : 'Non-aktif'}</strong>
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  {user.status === 'ACTIVE' ? (
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-rose-600 hover:bg-rose-50 border-rose-200"
                      icon={<Lock className="w-3.5 h-3.5" />}
                      onClick={() => onOpenSuspend && onOpenSuspend(user.id, user.username)}
                    >
                      Kunci Akun
                    </Button>
                  ) : (
                    <Button
                      size="sm"
                      variant="outline"
                      className="text-emerald-700 hover:bg-emerald-50 border-emerald-200"
                      icon={<Unlock className="w-3.5 h-3.5" />}
                      onClick={() => onOpenRestore && onOpenRestore(user.id, user.username)}
                    >
                      Buka Kunci
                    </Button>
                  )}
                </div>
              </div>

              {/* Reason if suspended */}
              {user.status === 'SUSPENDED' && (
                <div className="p-3.5 rounded-xl bg-rose-50 border border-rose-200/80 text-rose-800 text-xs">
                  <strong>Alasan Penangguhan:</strong> {user.suspendedReason || 'Pelanggaran ketentuan layanan'}
                  {user.suspendedAt && (
                    <div className="text-[11px] text-rose-600 mt-1">
                      Waktu penangguhan: {new Date(user.suspendedAt).toLocaleString('id-ID')}
                    </div>
                  )}
                </div>
              )}

              {/* 4 Activity Metrics */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div className="p-3 rounded-xl bg-white border border-neutral-200/80 shadow-2xs">
                  <span className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider block">
                    Perangkat
                  </span>
                  <span className="text-xl font-black text-neutral-900 mt-1 block">
                    {user.counts.devices}
                  </span>
                </div>
                <div className="p-3 rounded-xl bg-white border border-neutral-200/80 shadow-2xs">
                  <span className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider block">
                    Total Pesan
                  </span>
                  <span className="text-xl font-black text-neutral-900 mt-1 block">
                    {user.counts.messages}
                  </span>
                </div>
                <div className="p-3 rounded-xl bg-white border border-neutral-200/80 shadow-2xs">
                  <span className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider block">
                    Grup Diikuti
                  </span>
                  <span className="text-xl font-black text-neutral-900 mt-1 block">
                    {user.counts.conversationMembers}
                  </span>
                </div>
                <div className="p-3 rounded-xl bg-white border border-neutral-200/80 shadow-2xs">
                  <span className="text-[11px] font-semibold text-neutral-400 uppercase tracking-wider block">
                    Dilaporkan
                  </span>
                  <span className={`text-xl font-black block ${user.counts.reportsReceived > 0 ? 'text-rose-600' : 'text-neutral-900'}`}>
                    {user.counts.reportsReceived}x
                  </span>
                </div>
              </div>

              {/* User Identity Details */}
              <div className="space-y-2">
                <h4 className="text-xs font-bold uppercase tracking-wider text-neutral-500">
                  Informasi Identitas & Registrasi
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                  <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-100 flex items-center justify-between">
                    <span className="text-neutral-400">Nomor Telepon</span>
                    <span className="font-semibold text-neutral-800">
                      {user.phoneNumber || 'Belum diatur'}
                    </span>
                  </div>
                  <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-100 flex items-center justify-between">
                    <span className="text-neutral-400">Email</span>
                    <span className="font-semibold text-neutral-800">
                      {user.email || 'Belum diatur'}
                    </span>
                  </div>
                  <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-100 flex items-center justify-between">
                    <span className="text-neutral-400">Tanggal Terdaftar</span>
                    <span className="font-semibold text-neutral-800">
                      {new Date(user.createdAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'long',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </span>
                  </div>
                  <div className="p-3 rounded-xl bg-neutral-50 border border-neutral-100 flex items-center justify-between">
                    <span className="text-neutral-400">Sesi Aktif</span>
                    <span className="font-semibold text-neutral-800">
                      {user.counts.sessions} sesi
                    </span>
                  </div>
                </div>
              </div>

              {/* Registered Devices List */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-neutral-500">
                    Daftar Perangkat Terdaftar ({user.devices.length})
                  </h4>
                </div>

                <div className="divide-y divide-neutral-100 border border-neutral-200/80 rounded-2xl overflow-hidden bg-white shadow-2xs">
                  {user.devices.length === 0 ? (
                    <div className="p-4 text-center text-xs text-neutral-400">
                      Belum ada perangkat yang terhubung.
                    </div>
                  ) : (
                    user.devices.map((device) => (
                      <div key={device.id} className="p-3.5 flex items-center justify-between gap-3 text-xs">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-xl bg-neutral-100 text-neutral-700 flex items-center justify-center flex-shrink-0">
                            <Smartphone className="w-4 h-4" />
                          </div>
                          <div>
                            <div className="font-bold text-neutral-900 flex items-center gap-2">
                              {device.deviceModel || device.name || 'Perangkat Tanpa Nama'}
                              <span className="text-[10px] px-1.5 py-0.2 rounded bg-neutral-100 text-neutral-600 font-mono">
                                {device.platform || 'UNKNOWN'}
                              </span>
                            </div>
                            <div className="text-[11px] text-neutral-400 flex items-center gap-2 mt-0.5">
                              <span>Versi: {device.appVersion || 'v1.0.0'}</span>
                              <span>•</span>
                              <span>OS: {device.osVersion || 'N/A'}</span>
                              {device.registrationIp && (
                                <>
                                  <span>•</span>
                                  <span>IP: {device.registrationIp}</span>
                                </>
                              )}
                            </div>
                          </div>
                        </div>

                        <div className="text-right">
                          <Badge variant={device.status === 'ACTIVE' ? 'success' : 'neutral'}>
                            {device.status}
                          </Badge>
                          {device.lastSeenAt && (
                            <div className="text-[10px] text-neutral-400 mt-1 flex items-center justify-end gap-1">
                              <Clock className="w-3 h-3" />
                              {new Date(device.lastSeenAt).toLocaleTimeString('id-ID', {
                                hour: '2-digit',
                                minute: '2-digit',
                              })}
                            </div>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </>
          ) : (
            <div className="py-8 text-center text-xs text-neutral-400">
              Data pengguna tidak ditemukan.
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-3.5 bg-neutral-50/70 border-t border-neutral-100 flex justify-end">
          <Button variant="outline" size="sm" onClick={onClose}>
            Tutup
          </Button>
        </div>
      </div>
    </div>
  );
}
