import { useMutation } from '@tanstack/react-query';
import { apiClient } from '../api/client';

export function useMediaUpload() {
  return useMutation({
    mutationFn: async (file: File): Promise<{ url: string; blobId: string; filename: string }> => {
      // Read file as base64
      const base64Data = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });

      const res = await apiClient.post('/admin/upload', {
        filename: file.name,
        mimeType: file.type || 'image/png',
        base64Data,
      });

      return res.data;
    },
  });
}
