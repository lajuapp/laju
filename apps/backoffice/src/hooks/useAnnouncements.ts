import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { SystemAnnouncement } from '../api/types';

export function useAnnouncementsList() {
  return useQuery({
    queryKey: ['admin', 'announcements'],
    queryFn: async (): Promise<SystemAnnouncement[]> => {
      const res = await apiClient.get('/admin/announcements');
      return res.data;
    },
  });
}

export function useCreateAnnouncement() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      title: string;
      content: string;
      type: string;
      isActive?: boolean;
    }) => {
      const res = await apiClient.post('/admin/announcements', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'announcements'] });
    },
  });
}

export function useUpdateAnnouncement() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...payload
    }: {
      id: string;
      title?: string;
      content?: string;
      type?: string;
      isActive?: boolean;
    }) => {
      const res = await apiClient.patch(`/admin/announcements/${id}`, payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'announcements'] });
    },
  });
}

export function useDeleteAnnouncement() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const res = await apiClient.delete(`/admin/announcements/${id}`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'announcements'] });
    },
  });
}
