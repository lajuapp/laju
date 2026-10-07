import React, { useState } from 'react';
import {
  LifeBuoy,
  Search,
  Filter,
  CheckCircle2,
  Clock,
  AlertTriangle,
  User,
  MessageSquare,
  ArrowRight,
  Send,
  ShieldCheck,
  RefreshCw,
  Smartphone,
  Check,
  X,
  FileText,
} from 'lucide-react';
import { useTicketsList, useUpdateTicket } from '../hooks/useTickets';
import { usePagination } from '../hooks/usePagination';
import { Badge } from '../components/ui/Badge';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Pagination } from '../components/ui/Pagination';
import { SupportTicketItem, TicketStatus, TicketPriority } from '../api/types';

export function TicketsPage() {
  const [statusFilter, setStatusFilter] = useState<'ALL' | TicketStatus>('OPEN');
  const [priorityFilter, setPriorityFilter] = useState<'ALL' | TicketPriority>('ALL');
  const [categoryFilter, setCategoryFilter] = useState<string>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Review & Response Modal State
  const [selectedTicket, setSelectedTicket] = useState<SupportTicketItem | null>(null);
  const [newStatus, setNewStatus] = useState<TicketStatus>('OPEN');
  const [newPriority, setNewPriority] = useState<TicketPriority>('MEDIUM');
  const [adminNotes, setAdminNotes] = useState('');
  const [responseMessage, setResponseMessage] = useState('');

  const { data: ticketsData, isLoading, refetch } = useTicketsList(
    statusFilter,
    priorityFilter,
    categoryFilter,
    searchQuery,
    1,
    100
  );

  const updateMutation = useUpdateTicket();

  const tickets = ticketsData?.data || [];
  const counts = ticketsData?.counts || { open: 0, inProgress: 0, resolved: 0, closed: 0 };

  const filteredTickets = tickets.filter((t) => {
    const q = searchQuery.toLowerCase();
    if (!q) return true;
    const codeMatch = t.ticketCode.toLowerCase().includes(q);
    const subjectMatch = t.subject.toLowerCase().includes(q);
    const messageMatch = t.message.toLowerCase().includes(q);
    const userMatch = t.user?.username?.toLowerCase().includes(q);
    return codeMatch || subjectMatch || messageMatch || userMatch;
  });

  const pagination = usePagination(filteredTickets, { initialPageSize: 10 });

  const handleOpenTicket = (ticket: SupportTicketItem) => {
    setSelectedTicket(ticket);
    setNewStatus(ticket.status);
    setNewPriority(ticket.priority);
    setAdminNotes(ticket.adminNotes || '');
    setResponseMessage(ticket.responseMessage || '');
  };

  const handleSaveTicket = () => {
    if (!selectedTicket) return;

    updateMutation.mutate(
      {
        id: selectedTicket.id,
        payload: {
          status: newStatus,
          priority: newPriority,
          adminNotes: adminNotes.trim() || undefined,
          responseMessage: responseMessage.trim() || undefined,
        },
      },
      {
        onSuccess: () => {
          setSelectedTicket(null);
        },
      }
    );
  };

  const getStatusBadge = (status: TicketStatus) => {
    switch (status) {
      case 'OPEN':
        return <Badge variant="warning">Baru (Open)</Badge>;
      case 'IN_PROGRESS':
        return <Badge variant="brand">Sedang Diproses</Badge>;
      case 'RESOLVED':
        return <Badge variant="success">Selesai</Badge>;
      case 'CLOSED':
        return <Badge variant="neutral">Ditutup</Badge>;
      default:
        return <Badge variant="neutral">{status}</Badge>;
    }
  };

  const getPriorityBadge = (priority: TicketPriority) => {
    switch (priority) {
      case 'CRITICAL':
        return <Badge variant="error">Kritis</Badge>;
      case 'HIGH':
        return <Badge variant="error">Tinggi</Badge>;
      case 'MEDIUM':
        return <Badge variant="warning">Sedang</Badge>;
      case 'LOW':
        return <Badge variant="neutral">Rendah</Badge>;
      default:
        return <Badge variant="neutral">{priority}</Badge>;
    }
  };

  const formatDate = (isoStr: string) => {
    try {
      const d = new Date(isoStr);
      return d.toLocaleString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return isoStr;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
              Pusat Tiket Bantuan Pengguna (Support Tickets)
            </h1>
            {counts.open > 0 && (
              <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200 animate-pulse">
                {counts.open} Tiket Baru
              </span>
            )}
          </div>
          <p className="text-xs text-neutral-500 mt-1">
            Kelola pengaduan teknis, kendala enkripsi, serta kirimkan balasan resmi langsung ke aplikasi mobile pengguna
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={() => refetch()}
          className="self-start sm:self-auto gap-1.5"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          Segarkan Data
        </Button>
      </div>

      {/* Summary KPI Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-4 shadow-xs">
          <div className="flex items-center justify-between text-neutral-500 mb-2">
            <span className="text-xs font-semibold">Total Tiket</span>
            <LifeBuoy className="w-4 h-4 text-neutral-400" />
          </div>
          <div className="text-2xl font-black text-neutral-900">
            {ticketsData?.total ?? 0}
          </div>
          <p className="text-[10px] text-neutral-400 mt-0.5">Semua tiket yang masuk</p>
        </div>

        <div className="bg-white rounded-2xl border border-amber-200/80 p-4 shadow-xs bg-amber-50/20">
          <div className="flex items-center justify-between text-amber-700 mb-2">
            <span className="text-xs font-semibold">Menunggu Review</span>
            <Clock className="w-4 h-4 text-amber-500" />
          </div>
          <div className="text-2xl font-black text-amber-800">
            {counts.open}
          </div>
          <p className="text-[10px] text-amber-600 mt-0.5">Status Baru (Open)</p>
        </div>

        <div className="bg-white rounded-2xl border border-brand-200/80 p-4 shadow-xs bg-brand-50/20">
          <div className="flex items-center justify-between text-brand-700 mb-2">
            <span className="text-xs font-semibold">Sedang Diproses</span>
            <MessageSquare className="w-4 h-4 text-brand-500" />
          </div>
          <div className="text-2xl font-black text-brand-900">
            {counts.inProgress}
          </div>
          <p className="text-[10px] text-brand-600 mt-0.5">Sedang ditangani tim</p>
        </div>

        <div className="bg-white rounded-2xl border border-neutral-200/80 p-4 shadow-xs">
          <div className="flex items-center justify-between text-neutral-500 mb-2">
            <span className="text-xs font-semibold">Terselesaikan</span>
            <CheckCircle2 className="w-4 h-4 text-brand-600" />
          </div>
          <div className="text-2xl font-black text-neutral-900">
            {counts.resolved}
          </div>
          <p className="text-[10px] text-neutral-400 mt-0.5">Solusi telah dikirim</p>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl border border-neutral-200/80 p-3 shadow-xs">
        {/* Search Input */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari kode tiket, subjek, pesan, username..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white"
          />
        </div>

        {/* Status Tabs */}
        <div className="flex flex-wrap items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          {(['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'ALL'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setStatusFilter(tab)}
              className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
                statusFilter === tab
                  ? 'bg-white text-neutral-900 shadow-xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              {tab === 'OPEN'
                ? `Baru (${counts.open})`
                : tab === 'IN_PROGRESS'
                ? `Diproses (${counts.inProgress})`
                : tab === 'RESOLVED'
                ? `Selesai (${counts.resolved})`
                : tab === 'CLOSED'
                ? `Ditutup (${counts.closed})`
                : 'Semua'}
            </button>
          ))}
        </div>
      </div>

      {/* Tickets Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Kode Tiket</th>
                <th className="px-5 py-3.5">Pengguna</th>
                <th className="px-5 py-3.5">Subjek & Pesan</th>
                <th className="px-5 py-3.5">Prioritas</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Waktu Masuk</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-neutral-400">
                    Memuat data tiket bantuan...
                  </td>
                </tr>
              ) : pagination.paginatedItems.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center">
                    <LifeBuoy className="w-8 h-8 text-neutral-300 mx-auto mb-2" />
                    <p className="text-xs font-semibold text-neutral-600">Tidak ada tiket bantuan yang ditemukan</p>
                    <p className="text-[11px] text-neutral-400 mt-0.5">
                      Belum ada laporan dari pengguna pada kategori filter ini
                    </p>
                  </td>
                </tr>
              ) : (
                pagination.paginatedItems.map((ticket) => (
                  <tr key={ticket.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="font-mono font-bold text-neutral-900">
                        {ticket.ticketCode}
                      </div>
                      <div className="text-[10px] text-neutral-400 mt-0.5 flex items-center gap-1">
                        <span className="px-1.5 py-0.5 rounded bg-neutral-100 text-neutral-600 font-medium">
                          {ticket.category || 'General'}
                        </span>
                        {ticket.appVersion && (
                          <span className="font-mono text-neutral-400">v{ticket.appVersion}</span>
                        )}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-brand-100 text-brand-800 flex items-center justify-center font-bold text-[11px] uppercase">
                          {ticket.user?.username ? ticket.user.username.substring(0, 2) : '??'}
                        </div>
                        <div>
                          <div className="font-bold text-neutral-900">
                            @{ticket.user?.username || 'Anonim'}
                          </div>
                          <div className="text-[10px] text-neutral-400">
                            {ticket.user?.phoneNumber || ticket.user?.email || 'ID: ' + ticket.userId.substring(0, 8)}
                          </div>
                        </div>
                      </div>
                    </td>

                    <td className="px-5 py-3.5 max-w-xs">
                      <div className="font-bold text-neutral-900 truncate">
                        {ticket.subject}
                      </div>
                      <div className="text-[11px] text-neutral-500 line-clamp-1 mt-0.5">
                        {ticket.message}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      {getPriorityBadge(ticket.priority)}
                    </td>

                    <td className="px-5 py-3.5">
                      {getStatusBadge(ticket.status)}
                    </td>

                    <td className="px-5 py-3.5 text-neutral-500 whitespace-nowrap">
                      {formatDate(ticket.createdAt)}
                    </td>

                    <td className="px-5 py-3.5 text-right whitespace-nowrap">
                      <Button
                        variant="primary"
                        size="sm"
                        onClick={() => handleOpenTicket(ticket)}
                        className="gap-1 text-xs"
                      >
                        Tinjau & Tanggapi
                        <ArrowRight className="w-3.5 h-3.5" />
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        {pagination.totalPages > 1 && (
          <div className="p-4 border-t border-neutral-100 flex items-center justify-between">
            <span className="text-xs text-neutral-500">
              Total {pagination.totalItems} tiket
            </span>
            <Pagination
              currentPage={pagination.currentPage}
              totalPages={pagination.totalPages}
              totalItems={pagination.totalItems}
              pageSize={pagination.pageSize}
              onPageChange={pagination.goToPage}
              onPageSizeChange={pagination.setPageSize}
            />
          </div>
        )}
      </div>

      {/* Review & Response Modal */}
      {selectedTicket && (
        <Modal
          isOpen={!!selectedTicket}
          onClose={() => setSelectedTicket(null)}
          title={`Detail Tiket: ${selectedTicket.ticketCode}`}
          description={`Pengirim: @${selectedTicket.user?.username || 'Anonim'} • Kategori: ${selectedTicket.category || 'General'}`}
          maxWidth="2xl"
        >
          <div className="space-y-4 text-xs">
            {/* User Info Bar */}
            <div className="p-3 bg-neutral-50 rounded-xl border border-neutral-200/80 flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-full bg-brand-500 text-white flex items-center justify-center font-bold text-xs uppercase">
                  {selectedTicket.user?.username ? selectedTicket.user.username.substring(0, 2) : '??'}
                </div>
                <div>
                  <div className="font-bold text-neutral-900">
                    @{selectedTicket.user?.username || 'Anonim'}
                  </div>
                  <div className="text-[10px] text-neutral-400">
                    Trust Score: {selectedTicket.user?.trustScore ?? 100}/100 • Status: {selectedTicket.user?.status || 'ACTIVE'}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <span className="text-[11px] text-neutral-500">Versi App:</span>
                <span className="font-mono font-semibold px-2 py-0.5 rounded bg-white border border-neutral-200 text-neutral-700">
                  {selectedTicket.appVersion || '1.0.0'}
                </span>
              </div>
            </div>

            {/* Ticket Content Box */}
            <div className="border border-neutral-200 rounded-xl p-4 bg-white space-y-2">
              <div className="text-[10px] uppercase font-bold text-neutral-400 tracking-wider">
                Subjek & Keluhan Pengguna
              </div>
              <h3 className="text-sm font-bold text-neutral-900">
                {selectedTicket.subject}
              </h3>
              <div className="p-3 rounded-xl bg-neutral-50 text-neutral-800 leading-relaxed whitespace-pre-wrap font-sans text-xs border border-neutral-100">
                {selectedTicket.message}
              </div>
              <div className="text-[10px] text-neutral-400">
                Diajukan pada: {formatDate(selectedTicket.createdAt)}
              </div>
            </div>

            {/* Status & Priority Editor */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block font-bold text-neutral-700 mb-1">
                  Status Tiket
                </label>
                <select
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value as TicketStatus)}
                  className="w-full px-3 py-2 rounded-xl border border-neutral-200 bg-white text-xs font-semibold focus:outline-none focus:border-brand-600"
                >
                  <option value="OPEN">Baru (OPEN)</option>
                  <option value="IN_PROGRESS">Sedang Ditangani (IN_PROGRESS)</option>
                  <option value="RESOLVED">Terselesaikan (RESOLVED)</option>
                  <option value="CLOSED">Ditutup (CLOSED)</option>
                </select>
              </div>

              <div>
                <label className="block font-bold text-neutral-700 mb-1">
                  Tingkat Prioritas
                </label>
                <select
                  value={newPriority}
                  onChange={(e) => setNewPriority(e.target.value as TicketPriority)}
                  className="w-full px-3 py-2 rounded-xl border border-neutral-200 bg-white text-xs font-semibold focus:outline-none focus:border-brand-600"
                >
                  <option value="LOW">Rendah (LOW)</option>
                  <option value="MEDIUM">Sedang (MEDIUM)</option>
                  <option value="HIGH">Tinggi (HIGH)</option>
                  <option value="CRITICAL">Kritis (CRITICAL)</option>
                </select>
              </div>
            </div>

            {/* Official Response Input */}
            <div>
              <label className="block font-bold text-neutral-900 mb-1">
                Tanggapan / Solusi Resmi untuk Pengguna
              </label>
              <p className="text-[11px] text-neutral-500 mb-1.5">
                Pesan ini akan dikirimkan sebagai notifikasi push & langsung tampil di riwayat tiket aplikasi mobile pengguna.
              </p>
              <textarea
                rows={3}
                value={responseMessage}
                onChange={(e) => setResponseMessage(e.target.value)}
                placeholder="Tuliskan jawaban atau solusi teknis kepada pengguna di sini..."
                className="w-full px-3 py-2 rounded-xl border border-neutral-200 bg-neutral-50/50 text-xs focus:outline-none focus:border-brand-600 focus:bg-white resize-none"
              />
            </div>

            {/* Internal Staff Notes */}
            <div>
              <label className="block font-bold text-neutral-700 mb-1">
                Catatan Internal Admin (Opsional)
              </label>
              <textarea
                rows={2}
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="Catatan rahasia untuk tim admin (tidak terlihat oleh pengguna)..."
                className="w-full px-3 py-2 rounded-xl border border-neutral-200 bg-neutral-50/50 text-xs focus:outline-none focus:border-neutral-900 focus:bg-white resize-none"
              />
            </div>

            {/* Footer Action Buttons */}
            <div className="pt-2 flex items-center justify-end gap-2 border-t border-neutral-100">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setSelectedTicket(null)}
              >
                Batal
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={handleSaveTicket}
                disabled={updateMutation.isPending}
                className="gap-1.5"
              >
                {updateMutation.isPending ? (
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <Send className="w-3.5 h-3.5" />
                )}
                Simpan & Kirim Tanggapan
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
