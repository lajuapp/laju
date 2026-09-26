import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Megaphone,
  Plus,
  Trash2,
  AlertCircle,
  Info,
  AlertTriangle,
  Wrench,
  CheckCircle,
} from 'lucide-react';
import {
  useAnnouncementsList,
  useCreateAnnouncement,
  useUpdateAnnouncement,
  useDeleteAnnouncement,
} from '../hooks/useAnnouncements';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { usePagination } from '../hooks/usePagination';

const announcementSchema = z.object({
  title: z.string().min(3, 'Judul pengumuman minimal 3 karakter'),
  content: z.string().min(5, 'Isi pengumuman minimal 5 karakter'),
  type: z.enum(['INFO', 'WARNING', 'MAINTENANCE']),
  targetType: z.enum(['ALL', 'SPECIFIC', 'BULK']).default('ALL'),
  targetUserIds: z.string().optional(),
  isActive: z.boolean().default(true),
});

type AnnouncementFormValues = z.infer<typeof announcementSchema>;

export function AnnouncementsPage() {
  const { data: announcements, isLoading } = useAnnouncementsList();
  const createAnnouncement = useCreateAnnouncement();
  const updateAnnouncement = useUpdateAnnouncement();
  const deleteAnnouncement = useDeleteAnnouncement();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [deleteModal, setDeleteModal] = useState<{
    isOpen: boolean;
    id: string;
    title: string;
  }>({ isOpen: false, id: '', title: '' });

  const pagination = usePagination(announcements || [], { initialPageSize: 10 });

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm<AnnouncementFormValues>({
    resolver: zodResolver(announcementSchema),
    defaultValues: {
      title: '',
      content: '',
      type: 'INFO',
      targetType: 'ALL',
      targetUserIds: '',
      isActive: true,
    },
  });

  const watchTargetType = watch('targetType');

  const onSubmit = async (data: AnnouncementFormValues) => {
    try {
      setErrorMessage(null);
      const payload: any = {
        title: data.title,
        content: data.content,
        type: data.type,
        targetType: data.targetType,
        isActive: data.isActive,
      };

      if (data.targetType !== 'ALL' && data.targetUserIds) {
        payload.targetUserIds = data.targetUserIds
          .split(/[\n,]+/)
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
      }

      await createAnnouncement.mutateAsync(payload);
      setIsModalOpen(false);
      reset();
    } catch (err: any) {
      setErrorMessage(
        err.response?.data?.message || 'Gagal membuat pengumuman baru'
      );
    }
  };

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    updateAnnouncement.mutate({ id, isActive: !currentStatus });
  };

  const handleOpenDelete = (id: string, title: string) => {
    setDeleteModal({ isOpen: true, id, title });
  };

  const handleConfirmDelete = () => {
    deleteAnnouncement.mutate(deleteModal.id, {
      onSuccess: () => {
        setDeleteModal({ isOpen: false, id: '', title: '' });
      },
    });
  };

  const getTypeBadge = (type: string) => {
    switch (type) {
      case 'WARNING':
        return <Badge variant="warning">Peringatan</Badge>;
      case 'MAINTENANCE':
        return <Badge variant="error">Pemeliharaan</Badge>;
      case 'INFO':
      default:
        return <Badge variant="brand">Informasi</Badge>;
    }
  };

  const getTargetBadge = (targetType?: string, count?: number) => {
    switch (targetType) {
      case 'SPECIFIC':
        return <Badge variant="neutral">Pengguna Khusus (1)</Badge>;
      case 'BULK':
        return <Badge variant="warning">Bulk ({count || 0} Pengguna)</Badge>;
      case 'ALL':
      default:
        return <Badge variant="brand">Semua Pengguna (Broadcast)</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Pengumuman Sistem (Announcements)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Kelola pengumuman resmi dan pesan pembaruan yang ditampilkan pada aplikasi mobile
          </p>
        </div>

        <Button
          variant="primary"
          icon={<Plus className="w-4 h-4" />}
          onClick={() => {
            setErrorMessage(null);
            reset();
            setIsModalOpen(true);
          }}
        >
          Buat Pengumuman
        </Button>
      </div>

      {/* Announcements Table */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Judul & Isi</th>
                <th className="px-5 py-3.5">Tipe</th>
                <th className="px-5 py-3.5">Target Penerima</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Dibuat Pada</th>
                <th className="px-5 py-3.5 text-right">Tindakan</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Memuat daftar pengumuman...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((item) => (
                  <tr key={item.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5 max-w-md">
                      <p className="font-bold text-neutral-900">{item.title}</p>
                      <p className="text-neutral-500 text-[11px] mt-0.5 line-clamp-2 leading-relaxed">
                        {item.content}
                      </p>
                    </td>
                    <td className="px-5 py-3.5">
                      {getTypeBadge(item.type)}
                    </td>
                    <td className="px-5 py-3.5">
                      {getTargetBadge(item.targetType, item.targetUserCount)}
                    </td>
                    <td className="px-5 py-3.5">
                      {item.isActive ? (
                        <Badge variant="success">Aktif Tayang</Badge>
                      ) : (
                        <Badge variant="neutral">Nonaktif</Badge>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(item.createdAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td className="px-5 py-3.5 text-right space-x-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleToggleActive(item.id, item.isActive)}
                      >
                        {item.isActive ? 'Nonaktifkan' : 'Aktifkan'}
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                        onClick={() => handleOpenDelete(item.id, item.title)}
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </Button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada pengumuman dibuat
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Footer */}
        <div className="px-5 pb-4">
          <Pagination
            currentPage={pagination.currentPage}
            totalPages={pagination.totalPages}
            totalItems={pagination.totalItems}
            pageSize={pagination.pageSize}
            onPageChange={pagination.goToPage}
            onPageSizeChange={pagination.setPageSize}
          />
        </div>
      </div>

      {/* Modal Buat Pengumuman Baru */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Buat Pengumuman Baru"
        description="Siarkan informasi atau pemeliharaan kepada seluruh pengguna aplikasi"
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Input
            label="Judul Pengumuman"
            placeholder="Contoh: Pemeliharaan Server Berkala"
            {...register('title')}
            error={errors.title?.message}
          />

          <div>
            <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
              Target Penerima Broadcast Push Notif
            </label>
            <select
              {...register('targetType')}
              className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 bg-white focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900"
            >
              <option value="ALL">📢 Semua Pengguna (Broadcast All Users)</option>
              <option value="SPECIFIC">👤 Satu Pengguna Khusus (Specific User)</option>
              <option value="BULK">👥 Daftar Banyak Pengguna (Bulk Users)</option>
            </select>
          </div>

          {watchTargetType === 'SPECIFIC' && (
            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                Username, Nomor Telepon, atau User ID Penerima
              </label>
              <Input
                placeholder="Contoh: @dimas atau 08123456789 atau user UUID"
                {...register('targetUserIds')}
              />
              <p className="text-[10px] text-neutral-400 mt-1">
                Push notifikasi dan pengumuman hanya akan dikirimkan ke perangkat akun pengguna ini.
              </p>
            </div>
          )}

          {watchTargetType === 'BULK' && (
            <div>
              <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
                Daftar Username, Nomor Telepon, atau User ID (Pisahkan dengan koma atau baris baru)
              </label>
              <textarea
                rows={3}
                placeholder="@dimas, @budi, 081234567890"
                {...register('targetUserIds')}
                className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
              />
              <p className="text-[10px] text-neutral-400 mt-1">
                Push notifikasi dan pengumuman akan dikirimkan serentak ke perangkat daftar pengguna di atas.
              </p>
            </div>
          )}

          <div>
            <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
              Tipe Pengumuman
            </label>
            <select
              {...register('type')}
              className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 bg-white focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900"
            >
              <option value="INFO">Informasi Biasa</option>
              <option value="WARNING">Peringatan Penting</option>
              <option value="MAINTENANCE">Jadwal Pemeliharaan</option>
            </select>
          </div>

          <div>
            <label className="block text-[11px] font-bold text-neutral-700 mb-1.5 uppercase tracking-wider">
              Isi Pesan Pengumuman
            </label>
            <textarea
              {...register('content')}
              rows={4}
              placeholder="Tuliskan detail pengumuman yang akan dibaca pengguna..."
              className="w-full text-xs rounded-xl border border-neutral-200 px-3 py-2 text-neutral-900 placeholder:text-neutral-400 focus:outline-none focus:ring-2 focus:ring-neutral-900/10 focus:border-neutral-900 transition-all resize-none"
            />
            {errors.content && (
              <p className="text-[11px] text-rose-600 font-medium mt-1">
                {errors.content.message}
              </p>
            )}
          </div>

          <div className="flex items-center gap-2 pt-1">
            <input
              type="checkbox"
              id="isActive"
              {...register('isActive')}
              className="rounded border-neutral-300 text-neutral-900 focus:ring-neutral-900 h-4 w-4"
            />
            <label htmlFor="isActive" className="text-xs text-neutral-700 font-medium cursor-pointer">
              Langsung aktifkan dan siarkan pengumuman ini
            </label>
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsModalOpen(false)}
            >
              Batal
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={createAnnouncement.isPending}
            >
              Simpan Pengumuman
            </Button>
          </div>
        </form>
      </Modal>

      {/* Modal Hapus Pengumuman */}
      <ConfirmModal
        isOpen={deleteModal.isOpen}
        onClose={() => setDeleteModal({ isOpen: false, id: '', title: '' })}
        onConfirm={handleConfirmDelete}
        title="Hapus Pengumuman"
        description={`Yakin ingin menghapus pengumuman "${deleteModal.title}"? Pengumuman tidak akan lagi ditampilkan pada perangkat pengguna.`}
        confirmText="Hapus Pengumuman"
        cancelText="Batal"
        variant="danger"
        isLoading={deleteAnnouncement.isPending}
      />
    </div>
  );
}
