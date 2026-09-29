import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Smile,
  Plus,
  Trash2,
  Upload,
  AlertCircle,
  Package,
  Layers,
  ChevronRight,
  X,
  Film,
  FolderUp,
  Eye,
  Copy,
  Check,
  Scissors,
} from 'lucide-react';
import {
  useStickerPacksList,
  useCreateStickerPack,
  useDeleteStickerPack,
  useAddStickerItem,
  useAddBulkStickers,
  useDeleteStickerItem,
} from '../hooks/useStickers';
import { useMediaUpload } from '../hooks/useMediaUpload';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { usePagination } from '../hooks/usePagination';
import { StickerPackItem, StickerItem } from '../api/types';
import { ApngFrameStudioModal } from '../components/stickers/ApngFrameStudioModal';
import { SpriteSheetExtractorModal } from '../components/stickers/SpriteSheetExtractorModal';
import { resolveMediaUrl } from '../api/client';

const packSchema = z.object({
  name: z.string().min(2, 'Nama paket stiker minimal 2 karakter'),
  publisher: z.string().min(2, 'Nama kreator/publisher minimal 2 karakter'),
  description: z.string().optional(),
});

type PackFormData = z.infer<typeof packSchema>;

const stickerItemSchema = z.object({
  name: z.string().min(2, 'Nama stiker minimal 2 karakter'),
  emoji: z.string().optional(),
});

type StickerItemFormData = z.infer<typeof stickerItemSchema>;

export function StickersPage() {
  const { data: packs, isLoading } = useStickerPacksList();
  const createPack = useCreateStickerPack();
  const deletePack = useDeleteStickerPack();
  const addSticker = useAddStickerItem();
  const addBulkStickers = useAddBulkStickers();
  const deleteSticker = useDeleteStickerItem();
  const mediaUpload = useMediaUpload();

  const [isPackModalOpen, setIsPackModalOpen] = useState(false);
  const [selectedPack, setSelectedPack] = useState<StickerPackItem | null>(null);
  const [isAddStickerModalOpen, setIsAddStickerModalOpen] = useState(false);
  const [isBulkModalOpen, setIsBulkModalOpen] = useState(false);
  const [isApngStudioOpen, setIsApngStudioOpen] = useState(false);
  const [isSpriteSheetExtractorOpen, setIsSpriteSheetExtractorOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // File upload state for Pack Cover
  const [packCoverFile, setPackCoverFile] = useState<File | null>(null);
  const [packCoverPreview, setPackCoverPreview] = useState<string | null>(null);

  // File upload state for Sticker Item
  const [stickerFile, setStickerFile] = useState<File | null>(null);
  const [stickerPreview, setStickerPreview] = useState<string | null>(null);

  // Bulk Sticker upload state
  const [bulkItems, setBulkItems] = useState<Array<{
    file: File;
    name: string;
    emoji: string;
    previewUrl: string;
  }>>([]);
  const [isUploadingBulk, setIsUploadingBulk] = useState(false);
  const [bulkProgress, setBulkProgress] = useState({ current: 0, total: 0 });

  const {
    register: registerPack,
    handleSubmit: handleSubmitPack,
    reset: resetPack,
    formState: { errors: packErrors },
  } = useForm<PackFormData>({
    resolver: zodResolver(packSchema),
  });

  const {
    register: registerSticker,
    handleSubmit: handleSubmitSticker,
    reset: resetSticker,
    formState: { errors: stickerErrors },
  } = useForm<StickerItemFormData>({
    resolver: zodResolver(stickerItemSchema),
  });

  const handlePackCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setPackCoverFile(file);
      setPackCoverPreview(URL.createObjectURL(file));
    }
  };

  const handleStickerFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setStickerFile(file);
      setStickerPreview(URL.createObjectURL(file));
    }
  };

  const onSubmitPack = async (data: PackFormData) => {
    setErrorMessage(null);
    try {
      let coverUrl: string | undefined = undefined;
      if (packCoverFile) {
        const uploadRes = await mediaUpload.mutateAsync(packCoverFile);
        coverUrl = uploadRes.url;
      }

      await createPack.mutateAsync({
        ...data,
        coverUrl,
      });

      setIsPackModalOpen(false);
      resetPack();
      setPackCoverFile(null);
      setPackCoverPreview(null);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Gagal membuat paket stiker');
    }
  };

  const onSubmitSticker = async (data: StickerItemFormData) => {
    if (!selectedPack) return;
    if (!stickerFile) {
      setErrorMessage('Pilih file gambar stiker terlebih dahulu');
      return;
    }

    setErrorMessage(null);
    try {
      const uploadRes = await mediaUpload.mutateAsync(stickerFile);
      await addSticker.mutateAsync({
        packId: selectedPack.id,
        name: data.name,
        imageUrl: uploadRes.url,
        emoji: data.emoji,
      });

      setIsAddStickerModalOpen(false);
      resetSticker();
      setStickerFile(null);
      setStickerPreview(null);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Gagal mengunggah stiker');
    }
  };

  const handleBulkFilesSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files) return;
    const files = Array.from(e.target.files);
    const newItems = files.map((file) => {
      const baseName = file.name.substring(0, file.name.lastIndexOf('.')) || file.name;
      const cleanName = baseName
        .replace(/[_-]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .replace(/\b\w/g, (c) => c.toUpperCase());

      return {
        file,
        name: cleanName || 'Stiker',
        emoji: '',
        previewUrl: URL.createObjectURL(file),
      };
    });

    setBulkItems((prev) => [...prev, ...newItems]);
  };

  const handleRemoveBulkItem = (index: number) => {
    setBulkItems((prev) => {
      const copy = [...prev];
      URL.revokeObjectURL(copy[index].previewUrl);
      copy.splice(index, 1);
      return copy;
    });
  };

  const handleUpdateBulkItem = (index: number, field: 'name' | 'emoji', value: string) => {
    setBulkItems((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], [field]: value };
      return copy;
    });
  };

  const onSubmitBulkStickers = async () => {
    if (!selectedPack || bulkItems.length === 0) return;
    setIsUploadingBulk(true);
    setBulkProgress({ current: 0, total: bulkItems.length });
    setErrorMessage(null);

    try {
      const uploadedItems: Array<{ name: string; imageUrl: string; emoji?: string }> = [];

      for (let i = 0; i < bulkItems.length; i++) {
        const item = bulkItems[i];
        setBulkProgress({ current: i + 1, total: bulkItems.length });
        const uploadRes = await mediaUpload.mutateAsync(item.file);
        uploadedItems.push({
          name: item.name.trim() || `Stiker ${i + 1}`,
          imageUrl: uploadRes.url,
          emoji: item.emoji.trim() || undefined,
        });
      }

      await addBulkStickers.mutateAsync({
        packId: selectedPack.id,
        items: uploadedItems,
      });

      bulkItems.forEach((b) => URL.revokeObjectURL(b.previewUrl));
      setBulkItems([]);
      setIsBulkModalOpen(false);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Gagal mengunggah stiker massal');
    } finally {
      setIsUploadingBulk(false);
    }
  };

  const [deletePackModal, setDeletePackModal] = useState<{
    isOpen: boolean;
    packId: string;
    name: string;
  }>({ isOpen: false, packId: '', name: '' });

  const [deleteStickerModal, setDeleteStickerModal] = useState<{
    isOpen: boolean;
    stickerId: string;
  }>({ isOpen: false, stickerId: '' });

  const handleOpenDeletePack = (id: string, name: string) => {
    setDeletePackModal({ isOpen: true, packId: id, name });
  };

  const handleConfirmDeletePack = () => {
    deletePack.mutate(deletePackModal.packId, {
      onSuccess: () => {
        if (selectedPack?.id === deletePackModal.packId) setSelectedPack(null);
        setDeletePackModal({ isOpen: false, packId: '', name: '' });
      },
    });
  };

  const handleOpenDeleteSticker = (id: string) => {
    setDeleteStickerModal({ isOpen: true, stickerId: id });
  };

  const handleConfirmDeleteSticker = () => {
    deleteSticker.mutate(deleteStickerModal.stickerId, {
      onSuccess: () => {
        setDeleteStickerModal({ isOpen: false, stickerId: '' });
      },
    });
  };

  const [previewSticker, setPreviewSticker] = useState<StickerItem | null>(null);
  const [previewBg, setPreviewBg] = useState<'checker' | 'dark' | 'light'>('checker');
  const [copiedUrl, setCopiedUrl] = useState(false);

  // Sync selectedPack with fresh query data
  const currentActivePack = packs?.find((p) => p.id === selectedPack?.id) || selectedPack;

  const packsPagination = usePagination(packs || [], { initialPageSize: 6 });
  const stickersPagination = usePagination(currentActivePack?.stickers || [], { initialPageSize: 18 });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Manajemen Stiker (Stickers & Packs)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Kelola koleksi paket stiker resmi dan ekspresi emoji obrolan LAJU Messenger
          </p>
        </div>

        <Button
          variant="primary"
          icon={<Plus className="w-4 h-4" />}
          onClick={() => {
            setErrorMessage(null);
            setPackCoverFile(null);
            setPackCoverPreview(null);
            setIsPackModalOpen(true);
          }}
        >
          Buat Paket Stiker Baru
        </Button>
      </div>

      {/* Main Content: Packs Grid + Detail Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Packs List (1 col) */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-5 shadow-xs h-fit space-y-3">
          <div className="flex items-center justify-between pb-3 border-b border-neutral-100">
            <h2 className="text-xs font-bold text-neutral-900 uppercase tracking-wider">
              Daftar Paket Stiker ({packs?.length ?? 0})
            </h2>
          </div>

          <div className="space-y-2">
            {isLoading ? (
              <p className="text-xs text-neutral-400 py-6 text-center">Memuat daftar paket...</p>
            ) : packsPagination.paginatedItems && packsPagination.paginatedItems.length > 0 ? (
              packsPagination.paginatedItems.map((pack) => {
                const isSelected = currentActivePack?.id === pack.id;
                return (
                  <div
                    key={pack.id}
                    onClick={() => setSelectedPack(pack)}
                    className={`flex items-center justify-between p-3 rounded-xl border transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-neutral-900 text-white border-neutral-900 shadow-sm'
                        : 'bg-neutral-50/50 border-neutral-100 hover:bg-neutral-100 text-neutral-800'
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-lg bg-neutral-200 overflow-hidden flex items-center justify-center flex-shrink-0">
                        {pack.coverUrl ? (
                          <img
                            src={resolveMediaUrl(pack.coverUrl)}
                            alt={pack.name}
                            className="w-full h-full object-cover"
                            onError={(e) => {
                              (e.target as HTMLElement).style.display = 'none';
                            }}
                          />
                        ) : (
                          <Smile className={`w-5 h-5 ${isSelected ? 'text-white' : 'text-neutral-500'}`} />
                        )}
                      </div>
                      <div className="min-w-0">
                        <p className={`text-xs font-bold truncate ${isSelected ? 'text-white' : 'text-neutral-900'}`}>
                          {pack.name}
                        </p>
                        <p className={`text-[11px] truncate ${isSelected ? 'text-neutral-300' : 'text-neutral-400'}`}>
                          {pack.publisher || 'LAJU'} • {pack.stickers?.length ?? 0} stiker
                        </p>
                      </div>
                    </div>

                    <ChevronRight className={`w-4 h-4 ${isSelected ? 'text-white' : 'text-neutral-400'}`} />
                  </div>
                );
              })
            ) : (
              <p className="text-xs text-neutral-400 py-6 text-center">
                Belum ada paket stiker
              </p>
            )}
          </div>

          {/* Packs Pagination */}
          {packsPagination.totalItems > packsPagination.pageSize && (
            <div className="pt-2 border-t border-neutral-100">
              <Pagination
                currentPage={packsPagination.currentPage}
                totalPages={packsPagination.totalPages}
                totalItems={packsPagination.totalItems}
                pageSize={packsPagination.pageSize}
                onPageChange={packsPagination.goToPage}
                className="flex-col !items-start"
              />
            </div>
          )}
        </div>

        {/* Selected Pack Stickers Detail (2 cols) */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-neutral-200/80 p-6 shadow-xs min-h-[400px] flex flex-col justify-between">
          {currentActivePack ? (
            <div>
              {/* Header of Active Pack */}
              <div className="flex items-center justify-between pb-4 border-b border-neutral-100">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl bg-neutral-100 overflow-hidden flex items-center justify-center border border-neutral-200/80">
                    {currentActivePack.coverUrl ? (
                      <img
                        src={resolveMediaUrl(currentActivePack.coverUrl)}
                        alt={currentActivePack.name}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as HTMLElement).style.display = 'none';
                        }}
                      />
                    ) : (
                      <Smile className="w-6 h-6 text-neutral-600" />
                    )}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h2 className="text-sm font-bold text-neutral-900">{currentActivePack.name}</h2>
                      <Badge variant="brand">{currentActivePack.stickers?.length ?? 0} item</Badge>
                    </div>
                    <p className="text-xs text-neutral-400 mt-0.5">
                      Kreator: {currentActivePack.publisher || 'LAJU Team'}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    icon={<Scissors className="w-3.5 h-3.5 text-cyan-600" />}
                    onClick={() => {
                      setErrorMessage(null);
                      setIsSpriteSheetExtractorOpen(true);
                    }}
                  >
                    Ekstraktor Sprite Sheet
                  </Button>

                  <Button
                    size="sm"
                    variant="outline"
                    icon={<Film className="w-3.5 h-3.5 text-indigo-600" />}
                    onClick={() => {
                      setErrorMessage(null);
                      setIsApngStudioOpen(true);
                    }}
                  >
                    Studio Animasi APNG
                  </Button>

                  <Button
                    size="sm"
                    variant="outline"
                    icon={<FolderUp className="w-3.5 h-3.5 text-emerald-600" />}
                    onClick={() => {
                      setErrorMessage(null);
                      setBulkItems([]);
                      setIsBulkModalOpen(true);
                    }}
                  >
                    Unggah Massal
                  </Button>

                  <Button
                    size="sm"
                    variant="outline"
                    icon={<Plus className="w-3.5 h-3.5" />}
                    onClick={() => {
                      setErrorMessage(null);
                      setStickerFile(null);
                      setStickerPreview(null);
                      setIsAddStickerModalOpen(true);
                    }}
                  >
                    Tambah Stiker
                  </Button>

                  <Button
                    size="sm"
                    variant="ghost"
                    className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                    onClick={() => handleOpenDeletePack(currentActivePack.id, currentActivePack.name)}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </Button>
                </div>
              </div>

              {/* Stickers Grid */}
              <div className="mt-5 space-y-4">
                {stickersPagination.paginatedItems && stickersPagination.paginatedItems.length > 0 ? (
                  <>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3.5">
                      {stickersPagination.paginatedItems.map((stk) => {
                        const ext = stk.imageUrl?.split('.').pop()?.toUpperCase() || 'PNG';
                        const isAnimated = ext === 'APNG' || ext === 'GIF' || ext === 'WEBP';
                        return (
                          <div
                            key={stk.id}
                            onClick={() => {
                              setPreviewSticker(stk);
                              setCopiedUrl(false);
                            }}
                            className="p-3 rounded-2xl border border-neutral-200/80 bg-white hover:border-neutral-400 hover:shadow-md transition-all flex flex-col items-center justify-between group relative cursor-pointer"
                          >
                            {/* Format Badge */}
                            <div className="absolute top-2 left-2 z-10">
                              <span
                                className={`text-[9px] font-bold px-1.5 py-0.5 rounded-md shadow-2xs ${
                                  isAnimated
                                    ? 'bg-indigo-600 text-white'
                                    : 'bg-neutral-100 text-neutral-600 border border-neutral-200'
                                }`}
                              >
                                {ext}
                              </span>
                            </div>

                            {/* Delete button */}
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleOpenDeleteSticker(stk.id);
                              }}
                              className="absolute top-2 right-2 p-1.5 rounded-lg bg-white/90 border border-neutral-200 text-neutral-400 hover:text-rose-600 opacity-0 group-hover:opacity-100 transition-opacity shadow-xs z-10"
                              title="Hapus stiker"
                            >
                              <X className="w-3.5 h-3.5" />
                            </button>

                            {/* Sticker Preview Stage with Transparency Checkerboard */}
                            <div
                              className="w-full aspect-square max-w-[110px] rounded-xl flex items-center justify-center p-2 relative overflow-hidden transition-transform duration-200 group-hover:scale-105 border border-neutral-100 mt-3"
                              style={{
                                backgroundColor: '#ffffff',
                                backgroundImage:
                                  'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)',
                                backgroundSize: '12px 12px',
                                backgroundPosition: '0 0, 0 6px, 6px -6px, -6px 0px',
                              }}
                            >
                              <img
                                src={resolveMediaUrl(stk.imageUrl)}
                                alt={stk.name}
                                className="max-w-full max-h-full object-contain filter drop-shadow-xs"
                                loading="lazy"
                                onError={(e) => {
                                  (e.target as HTMLElement).style.opacity = '0.3';
                                }}
                              />
                            </div>

                            <div className="mt-2.5 text-center w-full">
                              <p className="text-xs font-bold text-neutral-800 truncate" title={stk.name}>
                                {stk.name}
                              </p>
                              {stk.emoji ? (
                                <span className="text-[10px] font-mono text-neutral-500 bg-neutral-100 px-1.5 py-0.5 rounded-md inline-block mt-0.5 border border-neutral-200/50">
                                  :{stk.emoji}:
                                </span>
                              ) : (
                                <span className="text-[10px] text-neutral-400 inline-block mt-0.5">
                                  Klik untuk pratinjau
                                </span>
                              )}
                            </div>
                          </div>
                        );
                      })}
                    </div>

                    {stickersPagination.totalItems > stickersPagination.pageSize && (
                      <Pagination
                        currentPage={stickersPagination.currentPage}
                        totalPages={stickersPagination.totalPages}
                        totalItems={stickersPagination.totalItems}
                        pageSize={stickersPagination.pageSize}
                        pageSizeOptions={[12, 18, 36, 60]}
                        onPageChange={stickersPagination.goToPage}
                        onPageSizeChange={stickersPagination.setPageSize}
                      />
                    )}
                  </>
                ) : (
                  <div className="py-16 text-center text-xs text-neutral-400">
                    Paket ini belum memiliki item stiker. Klik "Tambah Stiker" untuk mengunggah.
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="py-24 text-center text-neutral-400 space-y-2">
              <Package className="w-8 h-8 mx-auto text-neutral-300" />
              <p className="text-xs font-medium">Pilih paket stiker di sebelah kiri untuk melihat dan mengelola isinya</p>
            </div>
          )}
        </div>
      </div>

      {/* Modal: Create Sticker Pack */}
      <Modal
        isOpen={isPackModalOpen}
        onClose={() => setIsPackModalOpen(false)}
        title="Buat Paket Stiker Baru"
        description="Daftarkan paket stiker baru sebelum mengunggah aset gambar stikernya"
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmitPack(onSubmitPack)} className="space-y-4">
          <Input
            label="Nama Paket Stiker"
            placeholder="Misal: Kucing Lucu / Emoji Ekspresi"
            error={packErrors.name?.message}
            {...registerPack('name')}
          />

          <Input
            label="Penerbit / Kreator (Publisher)"
            placeholder="LAJU Creative Team"
            error={packErrors.publisher?.message}
            {...registerPack('publisher')}
          />

          <Input
            label="Deskripsi Singkat"
            placeholder="Koleksi ekspresi stiker harian"
            {...registerPack('description')}
          />

          {/* Cover Upload */}
          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Ikon Cover Paket
            </label>
            <div className="border-2 border-dashed border-neutral-200 rounded-xl p-3 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-neutral-50/50">
              <input
                type="file"
                accept="image/png,image/webp"
                onChange={handlePackCoverChange}
                className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
              />
              {packCoverPreview ? (
                <div className="flex items-center justify-center gap-3">
                  <img
                    src={packCoverPreview}
                    alt="Preview"
                    className="w-12 h-12 rounded-lg object-contain border border-neutral-200"
                  />
                  <div className="text-left text-xs text-neutral-600">
                    <p className="font-bold truncate max-w-[200px]">{packCoverFile?.name}</p>
                    <p className="text-[10px] text-neutral-400">Klik untuk ganti icon</p>
                  </div>
                </div>
              ) : (
                <div className="space-y-0.5 text-neutral-500">
                  <Upload className="w-4 h-4 mx-auto text-neutral-400" />
                  <p className="text-xs font-medium">Pilih cover icon (PNG / WEBP)</p>
                </div>
              )}
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsPackModalOpen(false)}
            >
              Batal
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={createPack.isPending || mediaUpload.isPending}
            >
              Simpan Paket Stiker
            </Button>
          </div>
        </form>
      </Modal>

      {/* Modal: Add Sticker Item */}
      <Modal
        isOpen={isAddStickerModalOpen}
        onClose={() => setIsAddStickerModalOpen(false)}
        title="Unggah Item Stiker Baru"
        description={`Tambahkan stiker ke dalam paket "${currentActivePack?.name}"`}
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmitSticker(onSubmitSticker)} className="space-y-4">
          <Input
            label="Nama / Judul Stiker"
            placeholder="Misal: Jempol Kucing / Senyum Lebar"
            error={stickerErrors.name?.message}
            {...registerSticker('name')}
          />

          <Input
            label="Tag / Kode Reaksi (Opsional)"
            placeholder="Misal: thumbs_up / smile"
            {...registerSticker('emoji')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              File Gambar Stiker (Transparan PNG / WEBP)
            </label>
            <div className="border-2 border-dashed border-neutral-200 rounded-xl p-4 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-neutral-50/50">
              <input
                type="file"
                accept="image/png,image/webp,image/apng,image/gif"
                onChange={handleStickerFileChange}
                className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
              />
              {stickerPreview ? (
                <div className="flex items-center justify-center gap-3">
                  <img
                    src={stickerPreview}
                    alt="Preview"
                    className="w-16 h-16 object-contain border border-neutral-200 rounded-lg p-1 bg-white"
                  />
                  <div className="text-left text-xs text-neutral-600">
                    <p className="font-bold truncate max-w-[200px]">{stickerFile?.name}</p>
                    <p className="text-[10px] text-neutral-400">Klik untuk ganti file</p>
                  </div>
                </div>
              ) : (
                <div className="space-y-1 text-neutral-500">
                  <Upload className="w-5 h-5 mx-auto text-neutral-400" />
                  <p className="text-xs font-medium">Unggah file stiker (PNG transparan / APNG disarankan)</p>
                  <p className="text-[10px] text-neutral-400">Dimensi 512x512 px optimal</p>
                </div>
              )}
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsAddStickerModalOpen(false)}
            >
              Batal
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={addSticker.isPending || mediaUpload.isPending}
            >
              Unggah Stiker
            </Button>
          </div>
        </form>
      </Modal>

      {/* Modal: Unggah Massal Stiker (Non-APNG) */}
      <Modal
        isOpen={isBulkModalOpen}
        onClose={() => {
          if (!isUploadingBulk) {
            bulkItems.forEach((b) => URL.revokeObjectURL(b.previewUrl));
            setBulkItems([]);
            setIsBulkModalOpen(false);
          }
        }}
        title={`Unggah Massal Stiker (${currentActivePack?.name || 'Paket'})`}
        maxWidth="xl"
      >
        <div className="space-y-4">
          <p className="text-xs text-neutral-500">
            Pilih banyak file gambar sekaligus (PNG transparan atau WEBP). Nama stiker akan dibuat otomatis dari nama file dan dapat Anda sesuaikan.
          </p>

          {errorMessage && (
            <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{errorMessage}</span>
            </div>
          )}

          {/* Multi-file dropzone / input */}
          <div className="border-2 border-dashed border-neutral-300 rounded-xl p-5 text-center hover:border-emerald-500 transition-colors cursor-pointer relative bg-neutral-50/50">
            <input
              type="file"
              multiple
              accept="image/png,image/webp,image/jpeg"
              onChange={handleBulkFilesSelect}
              disabled={isUploadingBulk}
              className="absolute inset-0 opacity-0 cursor-pointer w-full h-full disabled:cursor-not-allowed"
            />
            <div className="space-y-1.5 text-neutral-600">
              <FolderUp className="w-8 h-8 mx-auto text-emerald-600" />
              <p className="text-xs font-bold text-neutral-800">
                Klik atau Seret Banyak Gambar ke Sini
              </p>
              <p className="text-[11px] text-neutral-400">
                Pilih sekaligus banyak gambar (PNG/WEBP transparan disarankan • 512x512 px)
              </p>
            </div>
          </div>

          {/* Selected Files Grid Preview */}
          {bulkItems.length > 0 && (
            <div className="space-y-2">
              <div className="flex items-center justify-between text-xs font-semibold text-neutral-700">
                <span>Daftar Stiker Siap Diunggah ({bulkItems.length} item)</span>
                {!isUploadingBulk && (
                  <button
                    type="button"
                    onClick={() => {
                      bulkItems.forEach((b) => URL.revokeObjectURL(b.previewUrl));
                      setBulkItems([]);
                    }}
                    className="text-[11px] text-rose-600 hover:text-rose-700"
                  >
                    Hapus Semua
                  </button>
                )}
              </div>

              <div className="max-h-64 overflow-y-auto space-y-2 pr-1 border border-neutral-200/80 rounded-xl p-2 bg-neutral-50/30">
                {bulkItems.map((item, idx) => (
                  <div
                    key={idx}
                    className="flex items-center gap-3 p-2 bg-white rounded-lg border border-neutral-200 shadow-xs"
                  >
                    <div className="w-12 h-12 rounded-lg bg-neutral-100 flex items-center justify-center border border-neutral-200 shrink-0 p-1">
                      <img
                        src={item.previewUrl}
                        alt={item.name}
                        className="w-full h-full object-contain"
                      />
                    </div>
                    <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-2">
                      <input
                        type="text"
                        value={item.name}
                        disabled={isUploadingBulk}
                        onChange={(e) => handleUpdateBulkItem(idx, 'name', e.target.value)}
                        placeholder="Nama stiker"
                        className="text-xs px-2.5 py-1.5 rounded-md border border-neutral-200 focus:outline-none focus:border-emerald-500 font-medium"
                      />
                      <input
                        type="text"
                        value={item.emoji}
                        disabled={isUploadingBulk}
                        onChange={(e) => handleUpdateBulkItem(idx, 'emoji', e.target.value)}
                        placeholder="Tag emoji opsional (misal: smile)"
                        className="text-xs px-2.5 py-1.5 rounded-md border border-neutral-200 focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    {!isUploadingBulk && (
                      <button
                        type="button"
                        onClick={() => handleRemoveBulkItem(idx)}
                        className="p-1 rounded text-neutral-400 hover:text-rose-600 shrink-0"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Progress bar during bulk upload */}
          {isUploadingBulk && (
            <div className="space-y-2 p-3 bg-emerald-50 rounded-xl border border-emerald-200">
              <div className="flex justify-between text-xs font-semibold text-emerald-800">
                <span>Mengunggah stiker ke server...</span>
                <span>{bulkProgress.current} / {bulkProgress.total}</span>
              </div>
              <div className="w-full bg-emerald-200 rounded-full h-2 overflow-hidden">
                <div
                  className="bg-emerald-600 h-2 rounded-full transition-all duration-300"
                  style={{ width: `${(bulkProgress.current / bulkProgress.total) * 100}%` }}
                />
              </div>
            </div>
          )}

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              disabled={isUploadingBulk}
              onClick={() => {
                bulkItems.forEach((b) => URL.revokeObjectURL(b.previewUrl));
                setBulkItems([]);
                setIsBulkModalOpen(false);
              }}
            >
              Batal
            </Button>
            <Button
              type="button"
              variant="primary"
              disabled={bulkItems.length === 0 || isUploadingBulk}
              isLoading={isUploadingBulk}
              onClick={onSubmitBulkStickers}
            >
              Unggah Semua ({bulkItems.length} Stiker)
            </Button>
          </div>
        </div>
      </Modal>

      {/* Modal: APNG Frame & Sprite Sheet Studio */}
      {currentActivePack && (
        <ApngFrameStudioModal
          isOpen={isApngStudioOpen}
          onClose={() => setIsApngStudioOpen(false)}
          packId={currentActivePack.id}
          packName={currentActivePack.name}
        />
      )}

      {/* Modal: Ekstraktor Sprite Sheet Atlas (Phaser Tools Engine) */}
      {currentActivePack && (
        <SpriteSheetExtractorModal
          isOpen={isSpriteSheetExtractorOpen}
          onClose={() => setIsSpriteSheetExtractorOpen(false)}
          packId={currentActivePack.id}
          packName={currentActivePack.name}
        />
      )}

      {/* Modal: Pratinjau Resolusi Tinggi & Penguji Animasi Stiker */}
      <Modal
        isOpen={!!previewSticker}
        onClose={() => setPreviewSticker(null)}
        title={previewSticker ? `Pratinjau Stiker: ${previewSticker.name}` : 'Pratinjau Stiker'}
        maxWidth="md"
      >
        {previewSticker && (
          <div className="space-y-4">
            {/* Background switcher for transparency test */}
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-neutral-500">Latar Belakang Pratinjau:</span>
              <div className="flex items-center gap-1.5 bg-neutral-100 p-1 rounded-xl">
                <button
                  type="button"
                  onClick={() => setPreviewBg('checker')}
                  className={`text-[11px] font-semibold px-2.5 py-1 rounded-lg transition-all ${
                    previewBg === 'checker'
                      ? 'bg-white text-neutral-900 shadow-xs'
                      : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Kotak Catur
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewBg('light')}
                  className={`text-[11px] font-semibold px-2.5 py-1 rounded-lg transition-all ${
                    previewBg === 'light'
                      ? 'bg-white text-neutral-900 shadow-xs'
                      : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Putih
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewBg('dark')}
                  className={`text-[11px] font-semibold px-2.5 py-1 rounded-lg transition-all ${
                    previewBg === 'dark'
                      ? 'bg-neutral-900 text-white shadow-xs'
                      : 'text-neutral-500 hover:text-neutral-900'
                  }`}
                >
                  Gelap
                </button>
              </div>
            </div>

            {/* Display Stage */}
            <div
              className="w-full h-64 rounded-2xl flex items-center justify-center p-6 border border-neutral-200/80 transition-colors relative overflow-hidden"
              style={{
                backgroundColor: previewBg === 'dark' ? '#0F172A' : '#ffffff',
                backgroundImage:
                  previewBg === 'checker'
                    ? 'linear-gradient(45deg, #f1f5f9 25%, transparent 25%), linear-gradient(-45deg, #f1f5f9 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #f1f5f9 75%), linear-gradient(-45deg, transparent 75%, #f1f5f9 75%)'
                    : undefined,
                backgroundSize: '16px 16px',
                backgroundPosition: '0 0, 0 8px, 8px -8px, -8px 0px',
              }}
            >
              <img
                src={resolveMediaUrl(previewSticker.imageUrl)}
                alt={previewSticker.name}
                className="max-w-full max-h-full object-contain filter drop-shadow-md select-none"
              />
            </div>

            {/* Details & Actions */}
            <div className="bg-neutral-50 rounded-xl p-3.5 border border-neutral-200/80 space-y-2 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-neutral-500">Nama Stiker:</span>
                <span className="font-bold text-neutral-900">{previewSticker.name}</span>
              </div>
              {previewSticker.emoji && (
                <div className="flex items-center justify-between">
                  <span className="text-neutral-500">Shortcut / Emoji:</span>
                  <span className="font-mono bg-white px-2 py-0.5 rounded border border-neutral-200 font-semibold">
                    :{previewSticker.emoji}:
                  </span>
                </div>
              )}
              <div className="flex items-center justify-between">
                <span className="text-neutral-500">Format File:</span>
                <span className="font-semibold text-neutral-700">
                  {previewSticker.imageUrl.split('.').pop()?.toUpperCase() || 'PNG'}
                </span>
              </div>
              <div className="flex items-center justify-between pt-1 border-t border-neutral-200">
                <span className="text-neutral-500">Direct URL:</span>
                <button
                  type="button"
                  onClick={() => {
                    navigator.clipboard.writeText(resolveMediaUrl(previewSticker.imageUrl));
                    setCopiedUrl(true);
                    setTimeout(() => setCopiedUrl(false), 2000);
                  }}
                  className="flex items-center gap-1 text-[11px] font-semibold text-emerald-600 hover:text-emerald-700 bg-white px-2 py-1 rounded border border-neutral-200 shadow-2xs"
                >
                  {copiedUrl ? (
                    <>
                      <Check className="w-3 h-3" /> Tersalin
                    </>
                  ) : (
                    <>
                      <Copy className="w-3 h-3" /> Salin URL
                    </>
                  )}
                </button>
              </div>
            </div>

            <div className="flex justify-between items-center pt-2">
              <Button
                variant="ghost"
                size="sm"
                className="text-rose-600 hover:bg-rose-50"
                onClick={() => {
                  const id = previewSticker.id;
                  setPreviewSticker(null);
                  handleOpenDeleteSticker(id);
                }}
              >
                <Trash2 className="w-4 h-4 mr-1.5" /> Hapus Stiker
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPreviewSticker(null)}
              >
                Tutup
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Modal Hapus Paket Stiker */}
      <ConfirmModal
        isOpen={deletePackModal.isOpen}
        onClose={() => setDeletePackModal({ isOpen: false, packId: '', name: '' })}
        onConfirm={handleConfirmDeletePack}
        title="Hapus Paket Stiker"
        description={`Yakin ingin menghapus paket stiker "${deletePackModal.name}" beserta seluruh stiker di dalamnya? Tindakan ini bersifat permanen.`}
        confirmText="Hapus Paket"
        cancelText="Batal"
        variant="danger"
        isLoading={deletePack.isPending}
      />

      {/* Modal Hapus Stiker Satuan */}
      <ConfirmModal
        isOpen={deleteStickerModal.isOpen}
        onClose={() => setDeleteStickerModal({ isOpen: false, stickerId: '' })}
        onConfirm={handleConfirmDeleteSticker}
        title="Hapus Item Stiker"
        description="Yakin ingin menghapus stiker ini dari paket?"
        confirmText="Hapus Stiker"
        cancelText="Batal"
        variant="danger"
        isLoading={deleteSticker.isPending}
      />
    </div>
  );
}
