import React, { useState, useMemo } from 'react';
import { Smartphone, Radio, Search, ShieldCheck, ShieldAlert, Trash2 } from 'lucide-react';
import { useDevicesList, useRevokeDevice } from '../hooks/useDevices';
import { usePagination } from '../hooks/usePagination';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { ConfirmModal } from '../components/ui/ConfirmModal';

export function DevicesPage() {
  const { data: devices, isLoading } = useDevicesList();
  const revokeDevice = useRevokeDevice();

  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ONLINE' | 'OFFLINE'>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  const [revokeModal, setRevokeModal] = useState<{
    isOpen: boolean;
    deviceId: string;
  }>({ isOpen: false, deviceId: '' });

  // Compute online status and filter
  const onlineCount = useMemo(() => {
    return devices ? devices.filter((d) => d.isOnline).length : 0;
  }, [devices]);

  const offlineCount = useMemo(() => {
    return devices ? devices.length - onlineCount : 0;
  }, [devices, onlineCount]);

  const filteredDevices = useMemo(() => {
    if (!devices) return [];
    return devices.filter((d) => {
      const matchesSearch =
        d.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (d.user?.username && d.user.username.toLowerCase().includes(searchQuery.toLowerCase()));

      if (!matchesSearch) return false;

      if (statusFilter === 'ONLINE') return d.isOnline;
      if (statusFilter === 'OFFLINE') return !d.isOnline;
      return true;
    });
  }, [devices, searchQuery, statusFilter]);

  const pagination = usePagination(filteredDevices, { initialPageSize: 10 });

  const handleOpenRevoke = (id: string) => {
    setRevokeModal({ isOpen: true, deviceId: id });
  };

  const handleConfirmRevoke = () => {
    revokeDevice.mutate(revokeModal.deviceId, {
      onSuccess: () => {
        setRevokeModal({ isOpen: false, deviceId: '' });
      },
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Daftar Perangkat (Devices)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Status koneksi online / offline dan manajemen sesi seluruh perangkat terdaftar
          </p>
        </div>

        {/* Realtime Stat Chips */}
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-800 border border-emerald-200/80 rounded-xl text-xs font-bold shadow-xs">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            Online: {onlineCount}
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-neutral-100 text-neutral-600 border border-neutral-200/80 rounded-xl text-xs font-bold shadow-xs">
            <span className="w-2 h-2 rounded-full bg-neutral-400"></span>
            Offline: {offlineCount}
          </div>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl border border-neutral-200/80 p-3 shadow-xs">
        {/* Search Input */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari Device ID atau username..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white"
          />
        </div>

        {/* Status Tabs */}
        <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          <button
            onClick={() => setStatusFilter('ALL')}
            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
              statusFilter === 'ALL'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-500 hover:text-neutral-900'
            }`}
          >
            Semua ({devices?.length ?? 0})
          </button>
          <button
            onClick={() => setStatusFilter('ONLINE')}
            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all flex items-center gap-1.5 ${
              statusFilter === 'ONLINE'
                ? 'bg-emerald-500 text-white shadow-xs'
                : 'text-neutral-500 hover:text-emerald-700'
            }`}
          >
            <span className={`w-1.5 h-1.5 rounded-full ${statusFilter === 'ONLINE' ? 'bg-white' : 'bg-emerald-500'}`}></span>
            Online ({onlineCount})
          </button>
          <button
            onClick={() => setStatusFilter('OFFLINE')}
            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all flex items-center gap-1.5 ${
              statusFilter === 'OFFLINE'
                ? 'bg-neutral-700 text-white shadow-xs'
                : 'text-neutral-500 hover:text-neutral-800'
            }`}
          >
            <span className={`w-1.5 h-1.5 rounded-full ${statusFilter === 'OFFLINE' ? 'bg-white' : 'bg-neutral-400'}`}></span>
            Offline ({offlineCount})
          </button>
        </div>
      </div>

      {/* Devices Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Device ID</th>
                <th className="px-5 py-3.5">Pemilik Akun</th>
                <th className="px-5 py-3.5">Status Koneksi</th>
                <th className="px-5 py-3.5">Status Sesi</th>
                <th className="px-5 py-3.5">Terakhir Aktif</th>
                <th className="px-5 py-3.5">Didaftarkan</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-neutral-400">
                    Memuat data perangkat...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((device) => (
                  <tr key={device.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5 font-mono text-[11px] font-bold text-neutral-900">
                      <div className="flex items-center gap-2">
                        <Smartphone className="w-4 h-4 text-neutral-400" />
                        {device.id}
                      </div>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="font-semibold text-neutral-800">
                        @{device.user?.username || 'user'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      {device.isOnline ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200/90 shadow-2xs">
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                          Online
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-neutral-100 text-neutral-500 border border-neutral-200/80">
                          <span className="w-1.5 h-1.5 rounded-full bg-neutral-400"></span>
                          Offline
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      {device.status === 'ACTIVE' ? (
                        <Badge variant="success">Aktif</Badge>
                      ) : device.status === 'REVOKED' ? (
                        <Badge variant="error">Nonaktif</Badge>
                      ) : (
                        <Badge variant="warning">{device.status}</Badge>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {device.lastSeenAt
                        ? new Date(device.lastSeenAt).toLocaleString('id-ID', {
                            dateStyle: 'short',
                            timeStyle: 'short',
                          })
                        : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(device.createdAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-5 py-3.5 text-right">
                      {device.status === 'ACTIVE' && (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                          onClick={() => handleOpenRevoke(device.id)}
                        >
                          Putus Sesi
                        </Button>
                      )}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada perangkat yang sesuai dengan filter
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="px-5 pb-4">
          <Pagination
            currentPage={pagination.currentPage}
            totalPages={pagination.totalPages}
            totalItems={pagination.totalItems}
            pageSize={pagination.pageSize}
            onPageChange={pagination.goToPage}
            onPageSizeChange={pagination.setPageSize}
          />
        </div>
      </div>

      {/* Modal Putus Sesi */}
      <ConfirmModal
        isOpen={revokeModal.isOpen}
        onClose={() => setRevokeModal({ isOpen: false, deviceId: '' })}
        onConfirm={handleConfirmRevoke}
        title="Putus Sesi Perangkat"
        description={`Yakin ingin memutuskan sesi perangkat ini (ID: ${revokeModal.deviceId})? Akun pada perangkat ini akan langsung dikeluarkan secara aman.`}
        confirmText="Putus Sesi"
        cancelText="Batal"
        variant="danger"
        isLoading={revokeDevice.isPending}
      />
    </div>
  );
}
