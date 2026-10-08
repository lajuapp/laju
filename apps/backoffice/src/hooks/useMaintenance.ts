import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { MaintenanceStats, MaintenanceResetRequest, MaintenanceResetResponse } from '../api/types';

export function useMaintenanceStats() {
  return useQuery({
    queryKey: ['admin', 'maintenance', 'stats'],
    queryFn: async (): Promise<MaintenanceStats> => {
      const res = await apiClient.get('/admin/maintenance/stats');
      return res.data;
    },
    refetchInterval: 15000,
  });
}

export function useMaintenanceReset() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: MaintenanceResetRequest): Promise<MaintenanceResetResponse> => {
      const res = await apiClient.post('/admin/maintenance/reset', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'maintenance', 'stats'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'devices'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'conversations'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'wallpapers'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickers'] });
    },
  });
}

export function useReseedDefaults() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (): Promise<MaintenanceResetResponse> => {
      const res = await apiClient.post('/admin/maintenance/reseed');
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'maintenance', 'stats'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'wallpapers'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickers'] });
    },
  });
}
