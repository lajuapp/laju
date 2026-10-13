import React, { useState } from 'react';
import {
  Users,
  Search,
  Lock,
  Unlock,
  Smartphone,
  MessageSquare,
  AlertTriangle,
  Eye,
  UserX,
  Calendar,
  Globe,
  FileText,
} from 'lucide-react';
import { useUsersList, useSuspendUser, useRestoreUser, useDeletedAccountsList } from '../hooks/useUsers';
import { usePagination } from '../hooks/usePagination';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { UserDetailModal } from '../components/users/UserDetailModal';

export function UsersPage() {
  const { data: users, isLoading: isLoadingUsers } = useUsersList();
  const { data: deletedAccounts, isLoading: isLoadingDeleted } = useDeletedAccountsList();
  const suspendUser = useSuspendUser();
  const restoreUser = useRestoreUser();

  const [activeTab, setActiveTab] = useState<'ACTIVE_DIRECTORY' | 'DELETED_ACCOUNTS'>('ACTIVE_DIRECTORY');
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

  // Filter Active Users
  const filteredUsers = (users || []).filter((u) => {
    const query = searchQuery.toLowerCase();
    const matchesSearch =
      u.username.toLowerCase().includes(query) ||
      u.id.toLowerCase().includes(query);
    const matchesStatus =
      statusFilter === 'ALL' ? true : u.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  // Filter Deleted Accounts
  const filteredDeleted = (deletedAccounts || []).filter((d) => {
    const query = searchQuery.toLowerCase();
    return (
      d.username.toLowerCase().includes(query) ||
      d.userId.toLowerCase().includes(query) ||
      d.reason.toLowerCase().includes(query)
    );
  });

  const usersPagination = usePagination(filteredUsers, { initialPageSize: 10 });
  const deletedPagination = usePagination(filteredDeleted, { initialPageSize: 10 });

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
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900 flex items-center gap-2">
            <Users className="w-5 h-5 text-neutral-800" />
            User Management & Directory
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Browse registered member accounts, enforce access suspensions, and review deleted account feedback.
          </p>
        </div>

        {/* View Switcher Tabs */}
        <div className="flex items-center gap-1 bg-neutral-200/80 p-1 rounded-xl">
          <button
            onClick={() => {
              setActiveTab('ACTIVE_DIRECTORY');
              setSearchQuery('');
            }}
            className={`flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
              activeTab === 'ACTIVE_DIRECTORY'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-600 hover:text-neutral-900'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            Registered Users ({users?.length ?? 0})
          </button>
          <button
            onClick={() => {
              setActiveTab('DELETED_ACCOUNTS');
              setSearchQuery('');
            }}
            className={`flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
              activeTab === 'DELETED_ACCOUNTS'
                ? 'bg-white text-rose-700 shadow-xs'
                : 'text-neutral-600 hover:text-neutral-900'
            }`}
          >
            <UserX className="w-3.5 h-3.5 text-rose-500" />
            Deleted Accounts & Reasons ({deletedAccounts?.length ?? 0})
          </button>
        </div>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl border border-neutral-200/80 p-3 shadow-xs">
        {/* Search Input */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder={
              activeTab === 'ACTIVE_DIRECTORY'
                ? 'Search username or User ID...'
                : 'Search username, ID, or deletion reason...'
            }
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white"
          />
        </div>

        {/* Status Tabs (Only on Registered Directory) */}
        {activeTab === 'ACTIVE_DIRECTORY' && (
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
                {tab === 'ALL' ? 'All' : tab === 'ACTIVE' ? 'Active' : 'Suspended'}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Tab 1: Registered Users Table */}
      {activeTab === 'ACTIVE_DIRECTORY' && (
        <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
                <tr>
                  <th className="px-5 py-3.5">User</th>
                  <th className="px-5 py-3.5">User ID</th>
                  <th className="px-5 py-3.5">Status</th>
                  <th className="px-5 py-3.5">Trust Score</th>
                  <th className="px-5 py-3.5">Devices</th>
                  <th className="px-5 py-3.5">Messages</th>
                  <th className="px-5 py-3.5">Registered</th>
                  <th className="px-5 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-neutral-100">
                {isLoadingUsers ? (
                  <tr>
                    <td colSpan={8} className="px-5 py-8 text-center text-neutral-400">
                      Loading user directory...
                    </td>
                  </tr>
                ) : usersPagination.paginatedItems && usersPagination.paginatedItems.length > 0 ? (
                  usersPagination.paginatedItems.map((user) => {
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
                            <Badge variant="success">Active</Badge>
                          ) : user.status === 'SUSPENDED' ? (
                            <div className="flex flex-col items-start gap-1">
                              <Badge variant="error">Suspended</Badge>
                              {user.suspendedReason && (
                                <span className="text-[10px] text-neutral-400 max-w-[130px] truncate" title={user.suspendedReason}>
                                  {user.suspendedReason}
                                </span>
                              )}
                            </div>
                          ) : (
                            <Badge variant="neutral">Deactivated</Badge>
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
                          {new Date(user.createdAt).toLocaleDateString('en-US', {
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
                              title="Inspect Account Details"
                            >
                              Details
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
                                Restore
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
                      No registered users found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination Footer */}
          <div className="px-5 pb-4">
            <Pagination
              currentPage={usersPagination.currentPage}
              totalPages={usersPagination.totalPages}
              totalItems={usersPagination.totalItems}
              pageSize={usersPagination.pageSize}
              onPageChange={usersPagination.goToPage}
              onPageSizeChange={usersPagination.setPageSize}
            />
          </div>
        </div>
      )}

      {/* Tab 2: Deleted Accounts Table */}
      {activeTab === 'DELETED_ACCOUNTS' && (
        <div className="space-y-4">
          <div className="bg-amber-50/70 border border-amber-200/80 rounded-2xl p-4 flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
            <div className="text-xs text-amber-900">
              <p className="font-bold">Privacy Compliance & Account Deletion Audit</p>
              <p className="text-amber-700 mt-0.5">
                When users delete their account through the mobile app, all personal identity data, cryptokeys, and messages are permanently purged from the production cluster. The audit log below records only the anonymized reason and deletion timestamp for quality and compliance oversight.
              </p>
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
                  <tr>
                    <th className="px-5 py-3.5">Deleted User</th>
                    <th className="px-5 py-3.5">User ID</th>
                    <th className="px-5 py-3.5">Deletion Reason</th>
                    <th className="px-5 py-3.5">Date & Time</th>
                    <th className="px-5 py-3.5">IP Address</th>
                    <th className="px-5 py-3.5 text-right">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-neutral-100">
                  {isLoadingDeleted ? (
                    <tr>
                      <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                        Loading deleted accounts log...
                      </td>
                    </tr>
                  ) : deletedPagination.paginatedItems && deletedPagination.paginatedItems.length > 0 ? (
                    deletedPagination.paginatedItems.map((item) => (
                      <tr key={item.id} className="hover:bg-neutral-50/50 transition-colors">
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-neutral-200 text-neutral-600 flex items-center justify-center font-bold text-xs uppercase">
                              {item.username.substring(0, 2)}
                            </div>
                            <div>
                              <span className="font-bold text-neutral-900 block">
                                @{item.username}
                              </span>
                              <span className="text-[10px] text-neutral-400">Account Purged</span>
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 font-mono text-[11px] text-neutral-400">
                          {item.userId ? `${item.userId.substring(0, 12)}...` : 'N/A'}
                        </td>
                        <td className="px-5 py-3.5">
                          <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-neutral-100 border border-neutral-200/80 text-neutral-800 font-medium text-xs max-w-sm">
                            <FileText className="w-3.5 h-3.5 text-neutral-500 flex-shrink-0" />
                            <span>{item.reason}</span>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 text-neutral-600 text-[11px]">
                          <div className="flex items-center gap-1">
                            <Calendar className="w-3 h-3 text-neutral-400" />
                            <span>
                              {new Date(item.deletedAt).toLocaleDateString('en-US', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit',
                              })}
                            </span>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 font-mono text-[11px] text-neutral-500">
                          {item.ipAddress ? (
                            <span className="flex items-center gap-1">
                              <Globe className="w-3 h-3 text-neutral-400" />
                              {item.ipAddress}
                            </span>
                          ) : (
                            <span className="text-neutral-400">Not recorded</span>
                          )}
                        </td>
                        <td className="px-5 py-3.5 text-right">
                          <Badge variant="error">Purged</Badge>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                        No deleted accounts recorded yet
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination Footer */}
            <div className="px-5 pb-4">
              <Pagination
                currentPage={deletedPagination.currentPage}
                totalPages={deletedPagination.totalPages}
                totalItems={deletedPagination.totalItems}
                pageSize={deletedPagination.pageSize}
                onPageChange={deletedPagination.goToPage}
                onPageSizeChange={deletedPagination.setPageSize}
              />
            </div>
          </div>
        </div>
      )}

      {/* Suspend User Modal */}
      <ConfirmModal
        isOpen={suspendModal.isOpen}
        onClose={() => setSuspendModal({ isOpen: false, userId: '', username: '' })}
        onConfirm={handleConfirmSuspend}
        title="Suspend User Account"
        description={`Are you sure you want to suspend @${suspendModal.username}? All active device sessions will be terminated immediately, and the user will see this suspension notice on their device.`}
        confirmText="Suspend Account"
        cancelText="Cancel"
        variant="danger"
        requiresInput={true}
        inputLabel="Suspension Reason (Visible to user)"
        inputPlaceholder="e.g., Suspicious activity, violation of Terms of Service, etc."
        initialInputValue="Violation of Terms of Service"
        isLoading={suspendUser.isPending}
      />

      {/* Restore User Modal */}
      <ConfirmModal
        isOpen={restoreModal.isOpen}
        onClose={() => setRestoreModal({ isOpen: false, userId: '', username: '' })}
        onConfirm={handleConfirmRestore}
        title="Restore User Account"
        description={`Restore and reactivate user @${restoreModal.username}? The user will be permitted to authenticate and connect to the network again.`}
        confirmText="Restore Account"
        cancelText="Cancel"
        variant="primary"
        isLoading={restoreUser.isPending}
      />

      {/* User 360° Detail Modal */}
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
