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
} from 'lucide-react';
import {
  useStickerPacksList,
  useCreateStickerPack,
  useDeleteStickerPack,
  useAddStickerItem,
  useDeleteStickerItem,
} from '../hooks/useStickers';
import { useMediaUpload } from '../hooks/useMediaUpload';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { StickerPackItem } from '../api/types';

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
  const deleteSticker = useDeleteStickerItem();
  const mediaUpload = useMediaUpload();

  const [isPackModalOpen, setIsPackModalOpen] = useState(false);
  const [selectedPack, setSelectedPack] = useState<StickerPackItem | null>(null);
  const [isAddStickerModalOpen, setIsAddStickerModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // File upload state for Pack Cover
  const [packCoverFile, setPackCoverFile] = useState<File | null>(null);
  const [packCoverPreview, setPackCoverPreview] = useState<string | null>(null);

  // File upload state for Sticker Item
  const [stickerFile, setStickerFile] = useState<File | null>(null);
  const [stickerPreview, setStickerPreview] = useState<string | null>(null);

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

  const handleDeletePack = (id: string, name: string) => {
    if (confirm(`Hapus paket stiker "${name}" beserta seluruh isinya?`)) {
      deletePack.mutate(id);
      if (selectedPack?.id === id) setSelectedPack(null);
    }
  };

  const handleDeleteStickerItem = (id: string) => {
    if (confirm('Hapus stiker ini?')) {
      deleteSticker.mutate(id);
    }
  };

  // Sync selectedPack with fresh query data
  const currentActivePack = packs?.find((p) => p.id === selectedPack?.id) || selectedPack;

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
            ) : packs && packs.length > 0 ? (
              packs.map((pack) => {
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
                          <img src={pack.coverUrl} alt={pack.name} className="w-full h-full object-cover" />
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
                        src={currentActivePack.coverUrl}
                        alt={currentActivePack.name}
                        className="w-full h-full object-cover"
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
                    onClick={() => handleDeletePack(currentActivePack.id, currentActivePack.name)}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </Button>
                </div>
              </div>

              {/* Stickers Grid */}
              <div className="mt-5">
                {currentActivePack.stickers && currentActivePack.stickers.length > 0 ? (
                  <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
                    {currentActivePack.stickers.map((stk) => (
                      <div
                        key={stk.id}
                        className="p-3 rounded-xl border border-neutral-100 bg-neutral-50/50 hover:bg-neutral-100/80 transition-all flex flex-col items-center justify-between group relative"
                      >
                        <button
                          onClick={() => handleDeleteStickerItem(stk.id)}
                          className="absolute top-1.5 right-1.5 p-1 rounded-md bg-white border border-neutral-200 text-neutral-400 hover:text-rose-600 opacity-0 group-hover:opacity-100 transition-opacity shadow-xs"
                        >
                          <X className="w-3 h-3" />
                        </button>

                        <div className="w-16 h-16 flex items-center justify-center p-1">
                          <img
                            src={stk.imageUrl}
                            alt={stk.name}
                            className="max-w-full max-h-full object-contain"
                          />
                        </div>

                        <div className="mt-2 text-center w-full">
                          <p className="text-[11px] font-bold text-neutral-800 truncate">{stk.name}</p>
                          {stk.emoji && (
                            <span className="text-xs">{stk.emoji}</span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
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
            label="Emoji Terkait (Opsional)"
            placeholder="Misal: 👍 atau 😂"
            {...registerSticker('emoji')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              File Gambar Stiker (Transparan PNG / WEBP)
            </label>
            <div className="border-2 border-dashed border-neutral-200 rounded-xl p-4 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-neutral-50/50">
              <input
                type="file"
                accept="image/png,image/webp,image/gif"
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
                  <p className="text-xs font-medium">Unggah file stiker (PNG transparan disarankan)</p>
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
    </div>
  );
}
