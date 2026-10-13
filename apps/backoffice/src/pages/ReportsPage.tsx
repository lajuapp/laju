import React, { useState } from 'react';
import {
  ShieldAlert,
  ShieldCheck,
  Search,
} from 'lucide-react';
import { useReportsList, useReviewReport } from '../hooks/useReports';
import { usePagination } from '../hooks/usePagination';
import { Badge } from '../components/ui/Badge';
import { Button } from '../components/ui/Button';
import { Pagination } from '../components/ui/Pagination';
import { UserReportItem } from '../api/types';

export function ReportsPage() {
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'REJECTED'>('PENDING');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedReport, setSelectedReport] = useState<UserReportItem | null>(null);
  const [reviewNotes, setReviewNotes] = useState('');
  const [scoreDeduction, setScoreDeduction] = useState(10);
  const [suspendUser, setSuspendUser] = useState(false);

  const { data: reportsData, isLoading } = useReportsList(statusFilter, 1, 100);
  const reviewMutation = useReviewReport();

  const reports = reportsData?.data || [];

  const filteredReports = reports.filter((r) => {
    const query = searchQuery.toLowerCase();
    const reporterMatch = r.reporter?.username?.toLowerCase().includes(query);
    const reportedMatch = r.reportedUser?.username?.toLowerCase().includes(query);
    const reasonMatch = r.reason.toLowerCase().includes(query);
    const categoryMatch = r.category.toLowerCase().includes(query);
    return !searchQuery || reporterMatch || reportedMatch || reasonMatch || categoryMatch;
  });

  const pagination = usePagination(filteredReports, { initialPageSize: 10 });

  const handleOpenReview = (report: UserReportItem) => {
    setSelectedReport(report);
    setReviewNotes('');
    setScoreDeduction(report.scoreDeduction || 10);
    setSuspendUser(false);
  };

  const handleConfirmReview = (action: 'APPROVE' | 'REJECT') => {
    if (!selectedReport) return;
    reviewMutation.mutate(
      {
        reportId: selectedReport.id,
        action,
        scoreDeduction: action === 'APPROVE' ? scoreDeduction : undefined,
        reviewNotes: reviewNotes.trim() || undefined,
        suspendUser: action === 'APPROVE' ? suspendUser : false,
      },
      {
        onSuccess: () => {
          setSelectedReport(null);
        },
      }
    );
  };

  const getCategoryBadge = (category: string) => {
    switch (category) {
      case 'SCAM':
        return <Badge variant="error">Fraud / Scam</Badge>;
      case 'HARASSMENT':
        return <Badge variant="warning">Harassment</Badge>;
      case 'SPAM':
        return <Badge variant="warning">Commercial Spam</Badge>;
      case 'IMPERSONATION':
        return <Badge variant="error">Impersonation</Badge>;
      case 'INAPPROPRIATE_CONTENT':
        return <Badge variant="warning">Inappropriate Content</Badge>;
      default:
        return <Badge variant="neutral">Other</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
              User Moderation & Reports
            </h1>
            {statusFilter === 'PENDING' && (reports.length > 0) && (
              <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200 animate-pulse">
                {reports.length} Action Needed
              </span>
            )}
          </div>
          <p className="text-xs text-neutral-500 mt-1">
            Investigate reported abuse, spam, and security misconduct to adjust Trust Scores or suspend malicious actors.
          </p>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-white rounded-2xl border border-neutral-200/80 p-3 shadow-xs">
        {/* Search Input */}
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-neutral-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search reporter, reported user, reason..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white"
          />
        </div>

        {/* Status Tabs */}
        <div className="flex items-center gap-1 bg-neutral-100 p-1 rounded-xl">
          {(['PENDING', 'APPROVED', 'REJECTED', 'ALL'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setStatusFilter(tab)}
              className={`px-3 py-1 text-xs font-semibold rounded-lg transition-all ${
                statusFilter === tab
                  ? 'bg-white text-neutral-900 shadow-xs'
                  : 'text-neutral-500 hover:text-neutral-900'
              }`}
            >
              {tab === 'PENDING'
                ? 'Pending Review'
                : tab === 'APPROVED'
                ? 'Approved'
                : tab === 'REJECTED'
                ? 'Dismissed'
                : 'All'}
            </button>
          ))}
        </div>
      </div>

      {/* Reports Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Reported User</th>
                <th className="px-5 py-3.5">Reporter</th>
                <th className="px-5 py-3.5">Category</th>
                <th className="px-5 py-3.5">Reason & Details</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Reported Date</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-neutral-400">
                    Loading reports list...
                  </td>
                </tr>
              ) : pagination.paginatedItems.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center">
                    <ShieldCheck className="w-8 h-8 text-neutral-300 mx-auto mb-2" />
                    <p className="text-xs font-semibold text-neutral-600">No user reports found</p>
                    <p className="text-[11px] text-neutral-400 mt-0.5">
                      All reports have been processed or no complaints submitted in this category
                    </p>
                  </td>
                </tr>
              ) : (
                pagination.paginatedItems.map((report) => (
                  <tr key={report.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-rose-100 text-rose-700 flex items-center justify-center font-bold text-[11px] uppercase">
                          {report.reportedUser?.username ? report.reportedUser.username.substring(0, 2) : '??'}
                        </div>
                        <div>
                          <div className="font-bold text-neutral-900">
                            @{report.reportedUser?.username || 'Unknown'}
                          </div>
                          <div className="text-[10px] text-neutral-400 font-mono">
                            Trust: {report.reportedUser?.trustScore ?? '?'}/100
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="font-semibold text-neutral-700">
                        @{report.reporter?.username || 'Anonymous'}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      {getCategoryBadge(report.category)}
                    </td>
                    <td className="px-5 py-3.5 max-w-xs">
                      <p className="text-neutral-700 truncate font-medium" title={report.reason}>
                        {report.reason}
                      </p>
                      {report.reviewNotes && (
                        <p className="text-[10px] text-neutral-400 truncate mt-0.5" title={report.reviewNotes}>
                          Staff Note: {report.reviewNotes}
                        </p>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      {report.status === 'PENDING' ? (
                        <Badge variant="warning">Pending</Badge>
                      ) : report.status === 'APPROVED' ? (
                        <Badge variant="success">Approved (-{report.scoreDeduction} pts)</Badge>
                      ) : (
                        <Badge variant="neutral">Dismissed</Badge>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-400 text-[11px] whitespace-nowrap">
                      {new Date(report.createdAt).toLocaleDateString('en-US', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td className="px-5 py-3.5 text-right">
                      {report.status === 'PENDING' ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-brand-700 hover:bg-brand-50 border-brand-200"
                          onClick={() => handleOpenReview(report)}
                        >
                          Review
                        </Button>
                      ) : (
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-neutral-500"
                          onClick={() => handleOpenReview(report)}
                        >
                          Details
                        </Button>
                      )}
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
              Total {pagination.totalItems} reports
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

      {/* Review Modal */}
      {selectedReport && (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-neutral-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl border border-neutral-200 shadow-2xl max-w-lg w-full overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-neutral-100 flex items-center justify-between bg-neutral-50/50">
              <div className="flex items-center gap-2">
                <ShieldAlert className="w-5 h-5 text-rose-600" />
                <h3 className="text-base font-bold text-neutral-900">
                  User Report Review
                </h3>
              </div>
              <button
                onClick={() => setSelectedReport(null)}
                className="text-xs text-neutral-400 hover:text-neutral-700"
              >
                ✕
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs">
              {/* Target & Reporter details */}
              <div className="grid grid-cols-2 gap-3 p-3.5 rounded-2xl bg-neutral-50 border border-neutral-100">
                <div>
                  <span className="text-[10px] uppercase font-bold text-neutral-400">Reported User</span>
                  <div className="font-bold text-neutral-900 text-sm mt-0.5">
                    @{selectedReport.reportedUser?.username || 'Unknown'}
                  </div>
                  <div className="text-[11px] text-neutral-500 mt-0.5">
                    Current Trust Score: <strong>{selectedReport.reportedUser?.trustScore ?? '?'}/100</strong>
                  </div>
                </div>

                <div>
                  <span className="text-[10px] uppercase font-bold text-neutral-400">Reporter</span>
                  <div className="font-bold text-neutral-900 text-sm mt-0.5">
                    @{selectedReport.reporter?.username || 'Anonymous'}
                  </div>
                  <div className="text-[11px] text-neutral-500 mt-0.5">
                    Category: {selectedReport.category}
                  </div>
                </div>
              </div>

              {/* Reported Reason */}
              <div>
                <label className="font-bold text-neutral-700 block mb-1">
                  Reported Details & Reason:
                </label>
                <div className="p-3 rounded-xl bg-neutral-100/70 text-neutral-800 font-mono text-[11px] leading-relaxed">
                  "{selectedReport.reason}"
                </div>
              </div>

              {selectedReport.status === 'PENDING' ? (
                <>
                  {/* Actions configuration */}
                  <div className="space-y-3 pt-2 border-t border-neutral-100">
                    <div>
                      <label className="font-bold text-neutral-700 block mb-1">
                        Trust Score Penalty:
                      </label>
                      <div className="flex items-center gap-2">
                        {[10, 20, 30, 50].map((deduction) => (
                          <button
                            key={deduction}
                            type="button"
                            onClick={() => setScoreDeduction(deduction)}
                            className={`px-3 py-1.5 rounded-xl border text-xs font-bold transition-all ${
                              scoreDeduction === deduction
                                ? 'bg-neutral-900 text-white border-neutral-900 shadow-2xs'
                                : 'bg-neutral-50 text-neutral-600 border-neutral-200 hover:bg-neutral-100'
                            }`}
                          >
                            -{deduction} Points
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="flex items-center gap-2 p-3 rounded-xl bg-rose-50/60 border border-rose-200">
                      <input
                        type="checkbox"
                        id="suspendUserCheckbox"
                        checked={suspendUser}
                        onChange={(e) => setSuspendUser(e.target.checked)}
                        className="rounded border-rose-300 text-rose-600 focus:ring-rose-500"
                      />
                      <label htmlFor="suspendUserCheckbox" className="text-xs font-bold text-rose-900 cursor-pointer">
                        Immediately suspend user account (Severe Violation)
                      </label>
                    </div>

                    <div>
                      <label className="font-bold text-neutral-700 block mb-1">
                        Admin Decision Notes (Optional):
                      </label>
                      <textarea
                        rows={2}
                        placeholder="Provide reasoning or internal rationale..."
                        value={reviewNotes}
                        onChange={(e) => setReviewNotes(e.target.value)}
                        className="w-full p-2.5 rounded-xl border border-neutral-200 bg-neutral-50/50 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:border-neutral-900 focus:bg-white text-xs"
                      />
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="pt-3 border-t border-neutral-100 flex items-center justify-between gap-3">
                    <Button
                      variant="outline"
                      size="sm"
                      className="text-neutral-600"
                      onClick={() => handleConfirmReview('REJECT')}
                      disabled={reviewMutation.isPending}
                    >
                      Dismiss Report
                    </Button>

                    <Button
                      size="sm"
                      className="bg-rose-600 hover:bg-rose-700 text-white"
                      onClick={() => handleConfirmReview('APPROVE')}
                      disabled={reviewMutation.isPending}
                    >
                      {reviewMutation.isPending
                        ? 'Processing...'
                        : suspendUser
                        ? 'Enforce Penalty & Suspend'
                        : `Deduct -${scoreDeduction} Score & Approve`}
                    </Button>
                  </div>
                </>
              ) : (
                <div className="p-4 rounded-xl bg-neutral-50 border border-neutral-100 space-y-2">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-neutral-700">Final Outcome:</span>
                    <Badge variant={selectedReport.status === 'APPROVED' ? 'success' : 'neutral'}>
                      {selectedReport.status}
                    </Badge>
                  </div>
                  {selectedReport.reviewNotes && (
                    <div className="text-neutral-600">
                      <strong>Admin Notes:</strong> {selectedReport.reviewNotes}
                    </div>
                  )}
                  {selectedReport.reviewedAt && (
                    <div className="text-neutral-400 text-[11px]">
                      Reviewed at {new Date(selectedReport.reviewedAt).toLocaleString('en-US')}
                    </div>
                  )}
                  <div className="pt-2 flex justify-end">
                    <Button size="sm" variant="outline" onClick={() => setSelectedReport(null)}>
                      Close
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
