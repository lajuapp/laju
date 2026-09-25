import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { AppSystemConfig } from '../api/types';

export function useAppConfig() {
  return useQuery({
    queryKey: ['admin', 'app-config'],
    queryFn: async (): Promise<AppSystemConfig> => {
      const res = await apiClient.get('/admin/app-config');
      return res.data;
    },
  });
}

export function useUpdateAppConfig() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: Partial<AppSystemConfig>) => {
      const res = await apiClient.patch('/admin/app-config', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'app-config'] });
    },
  });
}
