import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { DeviceItem } from '../api/types';

export function useDevicesList() {
  return useQuery({
    queryKey: ['admin', 'devices'],
    queryFn: async (): Promise<DeviceItem[]> => {
      const res = await apiClient.get('/admin/devices');
      return res.data;
    },
  });
}

export function useRevokeDevice() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (deviceId: string) => {
      const res = await apiClient.post(`/admin/devices/${deviceId}/revoke`);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'devices'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
