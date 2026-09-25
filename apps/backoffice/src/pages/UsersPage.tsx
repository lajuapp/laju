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
} from 'lucide-react';
import { useUsersList, useSuspendUser, useRestoreUser } from '../hooks/useUsers';
import { usePagination } from '../hooks/usePagination';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';

export function UsersPage() {
  const { data: users, isLoading } = useUsersList();
  const suspendUser = useSuspendUser();
  const restoreUser = useRestoreUser();

  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACTIVE' | 'SUSPENDED'>('ALL');

  const filteredUsers = (users || []).filter((u) => {
    const matchesSearch =
      u.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
      u.id.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus =
      statusFilter === 'ALL' ? true : u.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const pagination = usePagination(filteredUsers, { initialPageSize: 10 });

  const handleSuspend = (id: string, username: string) => {
    if (
      confirm(
        `KUNCI AKUN: Yakin ingin menangguhkan pengguna @${username}? Seluruh sesi perangkat aktif akan diputus secara instan.`
      )
    ) {
      suspendUser.mutate(id);
    }
  };

  const handleRestore = (id: string, username: string) => {
    if (confirm(`PULIHKAN AKUN: Aktifkan kembali pengguna @${username}?`)) {
      restoreUser.mutate(id);
    }
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
            Daftar seluruh akun pengguna terdaftar, status kriptografis, dan kendali penangguhan sesi
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
                <th className="px-5 py-3.5">Armada Device</th>
                <th className="px-5 py-3.5">Total Pesan</th>
                <th className="px-5 py-3.5">Terdaftar</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-neutral-400">
                    Memuat daftar pengguna...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((user) => (
                  <tr key={user.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-full bg-neutral-900 text-white flex items-center justify-center font-bold text-xs uppercase">
                          {user.username.substring(0, 2)}
                        </div>
                        <span className="font-bold text-neutral-900">@{user.username}</span>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 font-mono text-[11px] text-neutral-400">
                      {user.id.substring(0, 12)}...
                    </td>
                    <td className="px-5 py-3.5">
                      {user.status === 'ACTIVE' ? (
                        <Badge variant="success">Aktif</Badge>
                      ) : user.status === 'SUSPENDED' ? (
                        <Badge variant="error">Terkunci</Badge>
                      ) : (
                        <Badge variant="neutral">Deaktif</Badge>
                      )}
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
                      {user.status === 'ACTIVE' ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                          icon={<Lock className="w-3 h-3" />}
                          onClick={() => handleSuspend(user.id, user.username)}
                        >
                          Suspend
                        </Button>
                      ) : (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-emerald-700 hover:bg-emerald-50"
                          icon={<Unlock className="w-3 h-3" />}
                          onClick={() => handleRestore(user.id, user.username)}
                        >
                          Pulihkan
                        </Button>
                      )}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-neutral-400">
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
    </div>
  );
}
