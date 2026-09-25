import React, { useState } from 'react';
import { MessageSquare, Users, Lock, ShieldCheck, Clock } from 'lucide-react';
import { useConversationsList, useGroupsList } from '../hooks/useConversations';
import { usePagination } from '../hooks/usePagination';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';

export function ConversationsPage() {
  const [activeTab, setActiveTab] = useState<'ALL' | 'GROUPS'>('ALL');
  const { data: allConvs, isLoading: loadingAll } = useConversationsList();
  const { data: groupConvs, isLoading: loadingGroups } = useGroupsList();

  const convs = activeTab === 'ALL' ? allConvs : groupConvs;
  const isLoading = activeTab === 'ALL' ? loadingAll : loadingGroups;

  const pagination = usePagination(convs || [], { initialPageSize: 10 });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Audit Metadata Obrolan (Conversations & Groups)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Inspeksi metadata percakapan tanpa melanggar privasi enkripsi end-to-end (Zero-Knowledge)
          </p>
        </div>

        {/* Tabs */}
        <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          <button
            onClick={() => setActiveTab('ALL')}
            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
              activeTab === 'ALL'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-500 hover:text-neutral-900'
            }`}
          >
            Semua Obrolan
          </button>
          <button
            onClick={() => setActiveTab('GROUPS')}
            className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
              activeTab === 'GROUPS'
                ? 'bg-white text-neutral-900 shadow-xs'
                : 'text-neutral-500 hover:text-neutral-900'
            }`}
          >
            Grup Obrolan Saja
          </button>
        </div>
      </div>

      {/* Info Card */}
      <div className="p-4 rounded-2xl bg-amber-50/60 border border-amber-200/80 text-amber-900 text-xs flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Lock className="w-4 h-4 text-amber-600 flex-shrink-0" />
          <span>
            <strong>Enkripsi End-to-End Aktif:</strong> Konten teks dan media disimpan dalam bentuk ciphertext di database. Hanya anggota sah percakapan yang memegang kunci dekripsi.
          </span>
        </div>
        <Badge variant="warning">E2EE Protected</Badge>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Conversation ID</th>
                <th className="px-5 py-3.5">Tipe Obrolan</th>
                <th className="px-5 py-3.5">Anggota Berpartisipasi</th>
                <th className="px-5 py-3.5">Volume Pesan</th>
                <th className="px-5 py-3.5">Dibuat Pada</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-neutral-400">
                    Memuat metadata percakapan...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((c) => (
                  <tr key={c.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5 font-mono text-[11px] font-bold text-neutral-900">
                      <div className="flex items-center gap-2">
                        <MessageSquare className="w-4 h-4 text-neutral-400" />
                        {c.id}
                      </div>
                    </td>
                    <td className="px-5 py-3.5">
                      {c.type === 'GROUP' ? (
                        <Badge variant="brand">Grup</Badge>
                      ) : (
                        <Badge variant="neutral">Personal P2P</Badge>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      <div className="flex flex-wrap gap-1">
                        {c.members?.map((m, idx) => (
                          <span
                            key={idx}
                            className="bg-neutral-100 px-1.5 py-0.5 rounded text-[11px] text-neutral-700"
                          >
                            @{m.user?.username || 'user'}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="px-5 py-3.5 font-medium text-neutral-700">
                      {c._count?.messages ?? 0} pesan terenkripsi
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(c.createdAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada percakapan
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
