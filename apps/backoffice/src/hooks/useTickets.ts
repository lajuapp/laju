import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { SupportTicketItem, UpdateTicketPayload } from '../api/types';

interface ListTicketsResponse {
  data: SupportTicketItem[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  counts: {
    open: number;
    inProgress: number;
    resolved: number;
    closed: number;
  };
}

export function useTicketsList(
  status?: string,
  priority?: string,
  category?: string,
  search?: string,
  page: number = 1,
  limit: number = 20
) {
  return useQuery({
    queryKey: ['admin', 'tickets', status, priority, category, search, page, limit],
    queryFn: async (): Promise<ListTicketsResponse> => {
      const res = await apiClient.get('/admin/tickets', {
        params: {
          status: status === 'ALL' ? undefined : status,
          priority: priority === 'ALL' ? undefined : priority,
          category: category === 'ALL' ? undefined : category,
          search: search?.trim() ? search.trim() : undefined,
          page,
          limit,
        },
      });
      return res.data;
    },
  });
}

export function useTicketDetails(id?: string) {
  return useQuery({
    queryKey: ['admin', 'ticket', id],
    queryFn: async (): Promise<SupportTicketItem> => {
      const res = await apiClient.get(`/admin/tickets/${id}`);
      return res.data;
    },
    enabled: !!id,
  });
}

export function useUpdateTicket() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (args: { id: string; payload: UpdateTicketPayload }) => {
      const res = await apiClient.patch(`/admin/tickets/${args.id}`, args.payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'tickets'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'ticket'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
