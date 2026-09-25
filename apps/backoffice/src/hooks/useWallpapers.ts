import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { ChatWallpaperItem } from '../api/types';

export function useWallpapersList() {
  return useQuery({
    queryKey: ['admin', 'wallpapers'],
    queryFn: async (): Promise<ChatWallpaperItem[]> => {
      const res = await apiClient.get('/admin/wallpapers');
      return res.data;
    },
  });
}

export function useCreateWallpaper() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      name: string;
      category?: string;
      colorHex?: string;
      imageUrl?: string;
      thumbnailUrl?: string;
      isDefault?: boolean;
      isActive?: boolean;
      sortOrder?: number;
    }) => {
      const res = await apiClient.post('/admin/wallpapers', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'wallpapers'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}

export function useUpdateWallpaper() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...payload
    }: {
      id: string;
      name?: string;
      category?: string;
      colorHex?: string;
      imageUrl?: string;
      thumbnailUrl?: string;
      isDefault?: boolean;
      isActive?: boolean;
      sortOrder?: number;
    }) => {
      const res = await apiClient.patch(`/admin/wallpapers/${id}`, payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'wallpapers'] });
    },
  });
}

export function useDeleteWallpaper() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const res = await apiClient.delete(`/admin/wallpapers/${id}`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'wallpapers'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
