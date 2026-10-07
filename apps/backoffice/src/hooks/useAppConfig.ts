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

export function useUploadApk() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: {
      file: File;
      version?: string;
      minVersion?: string;
      forceUpdate?: boolean;
      releaseNotes?: string;
      onProgress?: (percent: number) => void;
    }) => {
      const formData = new FormData();
      formData.append('file', payload.file);
      if (payload.version) formData.append('version', payload.version);
      if (payload.minVersion) formData.append('minVersion', payload.minVersion);
      if (payload.forceUpdate !== undefined) formData.append('forceUpdate', String(payload.forceUpdate));
      if (payload.releaseNotes) formData.append('releaseNotes', payload.releaseNotes);

      const res = await apiClient.post('/admin/app-config/upload-apk', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        timeout: 600000,
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total && payload.onProgress) {
            const percent = Math.round((progressEvent.loaded * 100) / progressEvent.total);
            payload.onProgress(percent);
          }
        },
      });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'app-config'] });
    },
  });
}
