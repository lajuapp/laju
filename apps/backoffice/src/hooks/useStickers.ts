import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { StickerPackItem } from '../api/types';

export function useStickerPacksList() {
  return useQuery({
    queryKey: ['admin', 'stickerPacks'],
    queryFn: async (): Promise<StickerPackItem[]> => {
      const res = await apiClient.get('/admin/stickers/packs');
      return res.data;
    },
  });
}

export function useCreateStickerPack() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      name: string;
      description?: string;
      publisher?: string;
      coverUrl?: string;
      isActive?: boolean;
      sortOrder?: number;
    }) => {
      const res = await apiClient.post('/admin/stickers/packs', payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}

export function useUpdateStickerPack() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...payload
    }: {
      id: string;
      name?: string;
      description?: string;
      publisher?: string;
      coverUrl?: string;
      isActive?: boolean;
      sortOrder?: number;
    }) => {
      const res = await apiClient.patch(`/admin/stickers/packs/${id}`, payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
    },
  });
}

export function useDeleteStickerPack() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const res = await apiClient.delete(`/admin/stickers/packs/${id}`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}

export function useAddStickerItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      packId,
      name,
      imageUrl,
      emoji,
    }: {
      packId: string;
      name: string;
      imageUrl: string;
      emoji?: string;
    }) => {
      const res = await apiClient.post(`/admin/stickers/packs/${packId}/stickers`, {
        name,
        imageUrl,
        emoji,
      });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
    },
  });
}

export function useAddBulkStickers() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      packId,
      items,
    }: {
      packId: string;
      items: { name: string; imageUrl: string; emoji?: string }[];
    }) => {
      const res = await apiClient.post(`/admin/stickers/packs/${packId}/stickers/bulk`, {
        items,
      });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
    },
  });
}

export function useDeleteStickerItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const res = await apiClient.delete(`/admin/stickers/${id}`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
    },
  });
}

export function useUpdateStickerItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      name,
      emoji,
      imageUrl,
    }: {
      id: string;
      name?: string;
      emoji?: string;
      imageUrl?: string;
    }) => {
      const res = await apiClient.patch(`/admin/stickers/${id}`, {
        name,
        emoji,
        imageUrl,
      });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'stickerPacks'] });
    },
  });
}

