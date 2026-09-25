import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { AdminAuditEvent, SecurityEvent } from '../api/types';

export function useAuditLogs() {
  return useQuery({
    queryKey: ['admin', 'audit'],
    queryFn: async (): Promise<AdminAuditEvent[]> => {
      const res = await apiClient.get('/admin/audit');
      return res.data;
    },
  });
}

export function useSecurityEvents() {
  return useQuery({
    queryKey: ['admin', 'security-events'],
    queryFn: async (): Promise<SecurityEvent[]> => {
      const res = await apiClient.get('/admin/security-events');
      return res.data;
    },
  });
}
