import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { AdminUser, LoginResponse } from '../api/types';

export function useLogin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (credentials: { identifier: string; password: string }): Promise<LoginResponse> => {
      const res = await apiClient.post('/admin/auth/login', credentials);
      return res.data;
    },
    onSuccess: (data) => {
      localStorage.setItem('laju_admin_token', data.sessionToken);
      localStorage.setItem('laju_admin_user', JSON.stringify(data.admin));
      queryClient.setQueryData(['admin', 'me'], data.admin);
    },
  });
}

export function useAdminMe() {
  const token = localStorage.getItem('laju_admin_token');

  return useQuery({
    queryKey: ['admin', 'me'],
    queryFn: async (): Promise<AdminUser> => {
      const res = await apiClient.get('/admin/auth/me');
      return res.data;
    },
    enabled: !!token,
    staleTime: 5 * 60 * 1000,
    retry: false,
  });
}

export function useLogout() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      try {
        await apiClient.post('/admin/auth/logout');
      } catch (_) {}
    },
    onSettled: () => {
      localStorage.removeItem('laju_admin_token');
      localStorage.removeItem('laju_admin_user');
      queryClient.clear();
      window.location.href = '/login';
    },
  });
}

export function useChangePassword() {
  return useMutation({
    mutationFn: async (payload: { currentPassword: string; newPassword: string }) => {
      const res = await apiClient.post('/admin/auth/change-password', payload);
      return res.data;
    },
  });
}
