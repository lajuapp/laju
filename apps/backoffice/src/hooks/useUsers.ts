import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { UserItem } from '../api/types';

export function useUsersList() {
  return useQuery({
    queryKey: ['admin', 'users'],
    queryFn: async (): Promise<UserItem[]> => {
      const res = await apiClient.get('/admin/users');
      return res.data;
    },
  });
}

export function useSuspendUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (args: string | { userId: string; reason?: string }) => {
      const userId = typeof args === 'string' ? args : args.userId;
      const reason = typeof args === 'string' ? undefined : args.reason;
      const res = await apiClient.post(`/admin/users/${userId}/suspend`, { reason });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}

export function useRestoreUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (userId: string) => {
      const res = await apiClient.post(`/admin/users/${userId}/restore`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
