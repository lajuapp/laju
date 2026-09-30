import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { UserReportItem } from '../api/types';

interface ListReportsResponse {
  data: UserReportItem[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export function useReportsList(status?: string, page: number = 1, limit: number = 20) {
  return useQuery({
    queryKey: ['admin', 'reports', status, page, limit],
    queryFn: async (): Promise<ListReportsResponse> => {
      const res = await apiClient.get('/admin/reports', {
        params: { status: status === 'ALL' ? undefined : status, page, limit },
      });
      return res.data;
    },
  });
}

export function useReviewReport() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (args: {
      reportId: string;
      action: 'APPROVE' | 'REJECT';
      scoreDeduction?: number;
      reviewNotes?: string;
      suspendUser?: boolean;
    }) => {
      const { reportId, ...payload } = args;
      const res = await apiClient.post(`/admin/reports/${reportId}/review`, payload);
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] });
      queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
    },
  });
}
