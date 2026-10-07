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
      const CHUNK_SIZE = 15 * 1024 * 1024; // 15 MB per chunk (well below Cloudflare's 100MB limit)
      const fileSize = payload.file.size;
      const totalChunks = Math.ceil(fileSize / CHUNK_SIZE);

      // If file is > 15MB, use chunked upload to bypass Cloudflare 100MB limit
      if (totalChunks > 1) {
        const uploadId = `upload_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
        let lastResponse: any = null;

        for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          const start = chunkIndex * CHUNK_SIZE;
          const end = Math.min(start + CHUNK_SIZE, fileSize);
          const chunkBlob = payload.file.slice(start, end);

          const formData = new FormData();
          formData.append('chunk', chunkBlob, payload.file.name);
          formData.append('uploadId', uploadId);
          formData.append('chunkIndex', String(chunkIndex));
          formData.append('totalChunks', String(totalChunks));
          formData.append('filename', payload.file.name);
          if (payload.version) formData.append('version', payload.version);
          if (payload.minVersion) formData.append('minVersion', payload.minVersion);
          if (payload.forceUpdate !== undefined) formData.append('forceUpdate', String(payload.forceUpdate));
          if (payload.releaseNotes) formData.append('releaseNotes', payload.releaseNotes);

          const res = await apiClient.post('/admin/app-config/upload-apk-chunk', formData, {
            headers: {
              'Content-Type': 'multipart/form-data',
            },
            timeout: 180000,
            onUploadProgress: (progressEvent) => {
              if (progressEvent.total && payload.onProgress) {
                const chunkLoaded = progressEvent.loaded;
                const chunkTotal = progressEvent.total;
                const overallPercent = Math.min(
                  99,
                  Math.round(((start + (chunkLoaded / chunkTotal) * (end - start)) / fileSize) * 100)
                );
                payload.onProgress(overallPercent);
              }
            },
          });

          lastResponse = res.data;
        }

        if (payload.onProgress) {
          payload.onProgress(100);
        }

        return lastResponse;
      } else {
        // Direct upload for small files (<= 15MB)
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
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'app-config'] });
    },
  });
}
