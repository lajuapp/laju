import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { DashboardStats } from '../api/types';

export function useDashboardStats() {
  return useQuery({
    queryKey: ['admin', 'stats'],
    queryFn: async (): Promise<DashboardStats> => {
      const res = await apiClient.get('/admin/stats');
      return res.data;
    },
    refetchInterval: 30000, // auto refresh every 30s
  });
}
