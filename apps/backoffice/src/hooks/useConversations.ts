import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { ConversationItem } from '../api/types';

export function useConversationsList() {
  return useQuery({
    queryKey: ['admin', 'conversations'],
    queryFn: async (): Promise<ConversationItem[]> => {
      const res = await apiClient.get('/admin/conversations');
      return res.data;
    },
  });
}

export function useGroupsList() {
  return useQuery({
    queryKey: ['admin', 'groups'],
    queryFn: async (): Promise<ConversationItem[]> => {
      const res = await apiClient.get('/admin/groups');
      return res.data;
    },
  });
}
