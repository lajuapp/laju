import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { MarketingStats } from '../api/types';

export function useMarketingStats() {
  return useQuery({
    queryKey: ['admin', 'marketing-stats'],
    queryFn: async (): Promise<MarketingStats> => {
      const res = await apiClient.get('/admin/marketing-stats');
      return res.data;
    },
    refetchInterval: 30000,
  });
}
