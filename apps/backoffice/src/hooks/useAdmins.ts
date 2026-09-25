import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { AdminRole, AdminUser } from '../api/types';

export function useAdminsList() {
  return useQuery({
    queryKey: ['admin', 'admins'],
    queryFn: async (): Promise<AdminUser[]> => {
      const res = await apiClient.get('/admin/admins');
      return res.data;
    },
  });
}

export function useAdminRoles() {
  return useQuery({
    queryKey: ['admin', 'roles'],
    queryFn: async (): Promise<AdminRole[]> => {
      const res = await apiClient.get('/admin/roles');
      return res.data;
    },
  });
}

export function useCreateAdmin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      name: string;
      username: string;
      email: string;
      password: string;
      roleId: string;
    }): Promise<AdminUser> => {
      const res = await apiClient.post('/admin/admins', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'admins'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}

export function useUpdateAdmin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...payload
    }: {
      id: string;
      name?: string;
      username?: string;
      email?: string;
      password?: string;
      roleId?: string;
      isActive?: boolean;
    }) => {
      const res = await apiClient.patch(`/admin/admins/${id}`, payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'admins'] });
    },
  });
}

export function useDeleteAdmin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const res = await apiClient.delete(`/admin/admins/${id}`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'admins'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
