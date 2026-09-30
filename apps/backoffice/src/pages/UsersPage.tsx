import React, { useState } from 'react';
import {
  Users,
  Search,
  Lock,
  Unlock,
  Smartphone,
  MessageSquare,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Eye,
  ShieldCheck,
} from 'lucide-react';
import { useUsersList, useSuspendUser, useRestoreUser } from '../hooks/useUsers';
import { usePagination } from '../hooks/usePagination';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { UserDetailModal } from '../components/users/UserDetailModal';

export function UsersPage() {
  const { data: users, isLoading } = useUsersList();
  const suspendUser = useSuspendUser();
  const restoreUser = useRestoreUser();

  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACTIVE' | 'SUSPENDED'>('ALL');
  const [inspectUserId, setInspectUserId] = useState<string | null>(null);

  const [suspendModal, setSuspendModal] = useState<{
    isOpen: boolean;
    userId: string;
    username: string;
  }>({ isOpen: false, userId: '', username: '' });

  const [restoreModal, setRestoreModal] = useState<{
    isOpen: boolean;
    userId: string;
    username: string;
  }>({ isOpen: false, userId: '', username: '' });

  const filteredUsers = (users || []).filter((u) => {
    const matchesSearch =
      u.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus =
      statusFilter === 'ALL' ? true : u.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const pagination = usePagination(filteredUsers, { initialPageSize: 10 });

  const handleOpenSuspend = (id: string, username: string) => {
    setSuspendModal({ isOpen: true, userId: id, username });
  };

  const handleConfirmSuspend = (reason?: string) => {
    suspendUser.mutate(
      { userId: suspendModal.userId, reason },
      {
        onSuccess: () => {
          setSuspendModal({ isOpen: false, userId: '', username: '' });
        },
      }
    );
  };

  const handleOpenRestore = (id: string, username: string) => {
    setRestoreModal({ isOpen: true, userId: id, username });
  };

  const handleConfirmRestore = () => {
    restoreUser.mutate(restoreModal.userId, {
      onSuccess: () => {
        setRestoreModal({ isOpen: false, userId: '', username: '' });
      },
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Direktori Pengguna (User Directory)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Daftar seluruh akun pengguna terdaftar, status akun, dan pengaturan akses
          </p>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl border border-neutral-200/80 p-3 shadow-xs">
        {/* Search Input */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari username atau User ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white"
          />
        </div>

        {/* Status Tabs */}
        <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          {(['ALL', 'ACTIVE', 'SUSPENDED'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setStatusFilter(tab)}
              className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
                statusFilter === tab
                  ? 'bg-white text-neutral-900 shadow-xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              {tab === 'ALL' ? 'Semua' : tab === 'ACTIVE' ? 'Aktif' : 'Terkunci'}
            </button>
          ))}
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Pengguna</th>
                <th className="px-5 py-3.5">User ID</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Skor Trust</th>
                <th className="px-5 py-3.5">Perangkat</th>
                <th className="px-5 py-3.5">Total Pesan</th>
                <th className="px-5 py-3.5">Terdaftar</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="px-5 py-8 text-center text-neutral-400">
                    Memuat daftar pengguna...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((user) => {
                  const trust = user.trustScore ?? 100;
                  return (
                    <tr key={user.id} className="hover:bg-neutral-50/50 transition-colors">
                      <td className="px-5 py-3.5">
                        <button
                          type="button"
                          onClick={() => setInspectUserId(user.id)}
                          className="flex items-center gap-2.5 text-left group"
                        >
                          <div className="w-8 h-8 rounded-full bg-neutral-900 text-white flex items-center justify-center font-bold text-xs uppercase group-hover:ring-2 group-hover:ring-brand-500 transition-all">
                            {user.username.substring(0, 2)}
                          </div>
                          <span className="font-bold text-neutral-900 group-hover:text-brand-600 group-hover:underline">
                            @{user.username}
                          </span>
                        </button>
                      </td>
                      <td className="px-5 py-3.5 font-mono text-[11px] text-neutral-400">
                        {user.id.substring(0, 12)}...
                      </td>
                      <td className="px-5 py-3.5">
                        {user.status === 'ACTIVE' ? (
                          <Badge variant="success">Aktif</Badge>
                        ) : user.status === 'SUSPENDED' ? (
                          <div className="flex flex-col items-start gap-1">
                            <Badge variant="error">Terkunci</Badge>
                            {user.suspendedReason && (
                              <span className="text-[10px] text-neutral-400 max-w-[130px] truncate" title={user.suspendedReason}>
                                {user.suspendedReason}
                              </span>
                            )}
                          </div>
                        ) : (
                          <Badge variant="neutral">Deaktif</Badge>
                        )}
                      </td>
                      <td className="px-5 py-3.5">
                        <span
                          className={`inline-flex items-center gap-1 font-mono text-[11px] font-bold px-2 py-0.5 rounded-md ${
                            trust >= 80
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200/80'
                              : trust >= 50
                              ? 'bg-amber-50 text-amber-700 border border-amber-200/80'
                              : 'bg-rose-50 text-rose-700 border border-rose-200/80'
                          }`}
                        >
                          {trust}/100
                        </span>
                      </td>
                      <td className="px-5 py-3.5">
                        <span className="inline-flex items-center gap-1.5 text-neutral-600 font-medium">
                          <Smartphone className="w-3.5 h-3.5 text-neutral-400" />
                          {user._count.devices}
                        </span>
                      </td>
                      <td className="px-5 py-3.5">
                        <span className="inline-flex items-center gap-1.5 text-neutral-600 font-medium">
                          <MessageSquare className="w-3.5 h-3.5 text-neutral-400" />
                          {user._count.messages}
                        </span>
                      </td>
                      <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                        {new Date(user.createdAt).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </td>
                      <td className="px-5 py-3.5 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            size="sm"
                            variant="outline"
                            className="text-neutral-700 hover:bg-neutral-100"
                            icon={<Eye className="w-3 h-3" />}
                            onClick={() => setInspectUserId(user.id)}
                            title="Inspeksi Detail Akun"
                          >
                            Detail
                          </Button>
                          {user.status === 'ACTIVE' ? (
                            <Button
                              size="sm"
                              variant="outline"
                              className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                              icon={<Lock className="w-3 h-3" />}
                              onClick={() => handleOpenSuspend(user.id, user.username)}
                            >
                              Suspend
                            </Button>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              className="text-emerald-700 hover:bg-emerald-50"
                              icon={<Unlock className="w-3 h-3" />}
                              onClick={() => handleOpenRestore(user.id, user.username)}
                            >
                              Pulihkan
                            </Button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={8} className="px-5 py-8 text-center text-neutral-400">
                    Tidak ditemukan pengguna yang sesuai
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

      {/* Modal Suspend Akun */}
      <ConfirmModal
        isOpen={suspendModal.isOpen}
        onClose={() => setSuspendModal({ isOpen: false, userId: '', username: '' })}
        onConfirm={handleConfirmSuspend}
        title="Kunci / Tangguhkan Akun"
        description={`Yakin ingin menangguhkan pengguna @${suspendModal.username}? Seluruh sesi perangkat aktif akan diputus secara instan dan pengguna akan melihat alasan penangguhan ini di perangkatnya.`}
        confirmText="Tangguhkan Akun"
        cancelText="Batal"
        variant="danger"
        requiresInput={true}
        inputLabel="Alasan Penangguhan (Akan dilihat pengguna)"
        inputPlaceholder="Contoh: Aktivitas mencurigakan, pelanggaran ketentuan layanan, dll."
        initialInputValue="Pelanggaran ketentuan layanan"
        isLoading={suspendUser.isPending}
      />

      {/* Modal Pulihkan Akun */}
      <ConfirmModal
        isOpen={restoreModal.isOpen}
        onClose={() => setRestoreModal({ isOpen: false, userId: '', username: '' })}
        onConfirm={handleConfirmRestore}
        title="Pulihkan Akun Pengguna"
        description={`Aktifkan kembali akun pengguna @${restoreModal.username}? Pengguna akan diizinkan masuk kembali ke dalam aplikasi.`}
        confirmText="Pulihkan Akun"
        cancelText="Batal"
        variant="primary"
        isLoading={restoreUser.isPending}
      />

      {/* Modal Detail Profil Pengguna 360° */}
      <UserDetailModal
        userId={inspectUserId}
        isOpen={!!inspectUserId}
        onClose={() => setInspectUserId(null)}
        onOpenSuspend={(id, username) => handleOpenSuspend(id, username)}
        onOpenRestore={(id, username) => handleOpenRestore(id, username)}
      />
    </div>
  );
}
