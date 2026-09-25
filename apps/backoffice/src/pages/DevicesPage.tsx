import React, { useState } from 'react';
import { Smartphone, ShieldCheck, ShieldAlert, Trash2 } from 'lucide-react';
import { useDevicesList, useRevokeDevice } from '../hooks/useDevices';
import { usePagination } from '../hooks/usePagination';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { ConfirmModal } from '../components/ui/ConfirmModal';

export function DevicesPage() {
  const { data: devices, isLoading } = useDevicesList();
  const revokeDevice = useRevokeDevice();

  const [revokeModal, setRevokeModal] = useState<{
    isOpen: boolean;
    deviceId: string;
  }>({ isOpen: false, deviceId: '' });

  const pagination = usePagination(devices || [], { initialPageSize: 10 });

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
      <div>
        <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
          Daftar Perangkat (Devices)
        </h1>
        <p className="text-xs text-neutral-500 mt-1">
          Daftar perangkat pengguna yang terdaftar dan aktif terhubung ke aplikasi LAJU
        </p>
      </div>

      {/* Devices Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Device ID</th>
                <th className="px-5 py-3.5">Pemilik Akun</th>
                <th className="px-5 py-3.5">Status Sesi</th>
                <th className="px-5 py-3.5">Terakhir Aktif</th>
                <th className="px-5 py-3.5">Didaftarkan</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
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
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada perangkat tercatat
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
