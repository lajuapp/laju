import React from 'react';
import { ShieldAlert, Activity, Clock, Terminal } from 'lucide-react';
import { useAuditLogs, useSecurityEvents } from '../hooks/useSecurity';
import { Badge } from '../components/ui/Badge';

export function SecurityPage() {
  const { data: auditLogs, isLoading: loadingAudit } = useAuditLogs();
  const { data: securityEvents, isLoading: loadingEvents } = useSecurityEvents();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
          Keamanan & Log Audit Admin (Security & Audit Trail)
        </h1>
        <p className="text-xs text-neutral-500 mt-1">
          Rekaman tidak dapat diubah (immutable logs) seluruh operasi sensitif admin untuk kebutuhan kepatuhan
        </p>
      </div>

      {/* Audit Trail Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="px-5 py-4 border-b border-neutral-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Terminal className="w-4 h-4 text-neutral-600" />
            <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
              Jejak Audit Aktivitas Admin ({auditLogs?.length ?? 0})
            </h2>
          </div>
          <Badge variant="brand">Strict Auditing</Badge>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3">Waktu</th>
                <th className="px-5 py-3">Tindakan (Action)</th>
                <th className="px-5 py-3">Sumber Daya</th>
                <th className="px-5 py-3">Rincian Operasi</th>
                <th className="px-5 py-3">Alamat IP</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {loadingAudit ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-neutral-400">
                    Memuat log audit...
                  </td>
                </tr>
              ) : auditLogs && auditLogs.length > 0 ? (
                auditLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3 font-mono text-[11px] text-neutral-500 whitespace-nowrap">
                      {new Date(log.createdAt).toLocaleString('id-ID', {
                        day: '2-digit',
                        month: '2-digit',
                        hour: '2-digit',
                        minute: '2-digit',
                        second: '2-digit',
                      })}
                    </td>
                    <td className="px-5 py-3">
                      <span className="font-mono text-[11px] font-bold text-neutral-800 bg-neutral-100 px-1.5 py-0.5 rounded">
                        {log.action}
                      </span>
                    </td>
                    <td className="px-5 py-3 font-semibold text-neutral-700">
                      {log.resource}
                    </td>
                    <td className="px-5 py-3 font-mono text-[11px] text-neutral-600 max-w-md truncate">
                      {log.details}
                    </td>
                    <td className="px-5 py-3 font-mono text-[11px] text-neutral-400">
                      {log.ipAddress || '127.0.0.1'}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada log audit tercatat
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
