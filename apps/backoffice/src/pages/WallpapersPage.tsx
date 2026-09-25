import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Image as ImageIcon,
  Plus,
  Trash2,
  CheckCircle,
  Upload,
  AlertCircle,
  Sparkles,
} from 'lucide-react';
import {
  useWallpapersList,
  useCreateWallpaper,
  useUpdateWallpaper,
  useDeleteWallpaper,
} from '../hooks/useWallpapers';
import { useMediaUpload } from '../hooks/useMediaUpload';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { resolveMediaUrl } from '../api/client';

const wallpaperSchema = z.object({
  name: z.string().min(2, 'Nama wallpaper minimal 2 karakter'),
  category: z.string().min(1, 'Kategori harus dipilih'),
  colorHex: z.string().optional(),
  imageUrl: z.string().optional(),
  isDefault: z.boolean().default(false),
});

type WallpaperFormData = z.infer<typeof wallpaperSchema>;

export function WallpapersPage() {
  const { data: wallpapers, isLoading } = useWallpapersList();
  const createWallpaper = useCreateWallpaper();
  const updateWallpaper = useUpdateWallpaper();
  const deleteWallpaper = useDeleteWallpaper();
  const mediaUpload = useMediaUpload();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors },
  } = useForm<WallpaperFormData>({
    resolver: zodResolver(wallpaperSchema),
    defaultValues: {
      category: 'SOLID',
      colorHex: '#0F172A',
      isDefault: false,
    },
  });

  const category = watch('category');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setSelectedFile(file);
      setPreviewUrl(URL.createObjectURL(file));
    }
  };

  const onSubmit = async (data: WallpaperFormData) => {
    setErrorMessage(null);
    try {
      let finalImageUrl = data.imageUrl;

      if (selectedFile) {
        const uploadRes = await mediaUpload.mutateAsync(selectedFile);
        finalImageUrl = uploadRes.url;
      }

      await createWallpaper.mutateAsync({
        ...data,
        imageUrl: finalImageUrl,
      });

      setIsModalOpen(false);
      reset();
      setSelectedFile(null);
      setPreviewUrl(null);
    } catch (err: any) {
      setErrorMessage(err.response?.data?.message || 'Gagal menyimpan wallpaper');
    }
  };

  const handleSetDefault = (id: string) => {
    updateWallpaper.mutate({ id, isDefault: true });
  };

  const handleDelete = (id: string, name: string) => {
    if (confirm(`Hapus wallpaper "${name}"?`)) {
      deleteWallpaper.mutate(id);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Manajemen Wallpaper Obrolan (Chat Backgrounds)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Kelola pilihan latar belakang pesan, warna solid, gradien, dan gambar ornamen aplikasi LAJU
          </p>
        </div>

        <Button
          variant="primary"
          icon={<Plus className="w-4 h-4" />}
          onClick={() => {
            setErrorMessage(null);
            setSelectedFile(null);
            setPreviewUrl(null);
            setIsModalOpen(true);
          }}
        >
          Tambah Wallpaper Baru
        </Button>
      </div>

      {/* Grid of Wallpapers */}
      {isLoading ? (
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-12 text-center text-xs text-neutral-400">
          Memuat daftar wallpaper...
        </div>
      ) : wallpapers && wallpapers.length > 0 ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {wallpapers.map((wp) => (
            <div
              key={wp.id}
              className="bg-white rounded-2xl border border-neutral-200/80 p-4 shadow-xs flex flex-col justify-between group hover:border-neutral-300 transition-all hover:shadow-sm"
            >
              {/* Preview Window Frame */}
              <div
                className="h-36 rounded-xl border border-neutral-200/70 overflow-hidden relative flex items-center justify-center shadow-inner"
                style={{
                  backgroundColor: wp.colorHex || '#1E293B',
                  backgroundImage: wp.imageUrl ? `url(${resolveMediaUrl(wp.imageUrl)})` : undefined,
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                }}
              >
                {wp.isDefault && (
                  <span className="absolute top-2 left-2 text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500 text-white shadow-sm flex items-center gap-1">
                    <CheckCircle className="w-3 h-3" />
                    Default
                  </span>
                )}
                <span className="absolute bottom-2 right-2 text-[10px] font-mono px-2 py-0.5 rounded bg-black/50 text-white backdrop-blur-xs">
                  {wp.category}
                </span>
              </div>

              {/* Meta Info */}
              <div className="mt-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-bold text-neutral-900 truncate">{wp.name}</h3>
                  {wp.colorHex && (
                    <span className="text-[10px] font-mono text-neutral-400">
                      {wp.colorHex}
                    </span>
                  )}
                </div>

                <div className="flex items-center justify-between mt-3 pt-3 border-t border-neutral-100">
                  {!wp.isDefault ? (
                    <button
                      onClick={() => handleSetDefault(wp.id)}
                      className="text-[11px] font-semibold text-neutral-500 hover:text-neutral-900"
                    >
                      Jadikan Default
                    </button>
                  ) : (
                    <span className="text-[11px] text-emerald-600 font-semibold">Aktif Standar</span>
                  )}

                  <button
                    onClick={() => handleDelete(wp.id, wp.name)}
                    className="p-1 rounded text-neutral-400 hover:text-rose-600 hover:bg-rose-50 transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-12 text-center text-xs text-neutral-400">
          Belum ada wallpaper tersimpan. Klik tombol Tambah Wallpaper untuk membuat baru.
        </div>
      )}

      {/* Add Wallpaper Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Tambah Wallpaper Chat Baru"
        description="Unggah tema latar belakang obrolan untuk dinikmati seluruh pengguna LAJU"
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <Input
            label="Nama Wallpaper"
            placeholder="Misal: Sunset Glow / Deep Slate"
            error={errors.name?.message}
            {...register('name')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Kategori Tipe
            </label>
            <select
              className="w-full px-3 py-2 text-xs rounded-xl border border-neutral-200 bg-white text-neutral-900 focus:outline-none focus:border-neutral-900"
              {...register('category')}
            >
              <option value="SOLID">Warna Solid (Solid Color)</option>
              <option value="GRADIENT">Warna Gradien (Gradient)</option>
              <option value="PATTERN">Pola Ornamen (Pattern / Doodle)</option>
              <option value="IMAGE">Gambar Kustom (Image Background)</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Kode Warna Hex
            </label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                className="w-8 h-8 rounded-lg cursor-pointer border border-neutral-200"
                value={watch('colorHex') || '#0F172A'}
                onChange={(e) => setValue('colorHex', e.target.value)}
              />
              <Input
                placeholder="#0F172A"
                {...register('colorHex')}
              />
            </div>
          </div>

          {/* File Upload Zone */}
          {(category === 'IMAGE' || category === 'PATTERN') && (
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-neutral-700">
                Unggah File Gambar Wallpaper
              </label>
              <div className="border-2 border-dashed border-neutral-200 rounded-xl p-4 text-center hover:border-neutral-400 transition-colors cursor-pointer relative bg-neutral-50/50">
                <input
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  onChange={handleFileChange}
                  className="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                />
                {previewUrl ? (
                  <div className="flex items-center justify-center gap-3">
                    <img
                      src={previewUrl}
                      alt="Preview"
                      className="w-16 h-16 rounded-lg object-cover border border-neutral-200"
                    />
                    <div className="text-left text-xs text-neutral-600">
                      <p className="font-bold truncate max-w-[200px]">{selectedFile?.name}</p>
                      <p className="text-[11px] text-neutral-400">Klik untuk ganti file</p>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-1 text-neutral-500">
                    <Upload className="w-5 h-5 mx-auto text-neutral-400" />
                    <p className="text-xs font-medium">Pilih file gambar (PNG, JPG, WEBP)</p>
                    <p className="text-[10px] text-neutral-400">Maksimal 5MB • Resolusi potret disarankan</p>
                  </div>
                )}
              </div>
            </div>
          )}

          <div className="flex items-center gap-2 pt-1">
            <input
              type="checkbox"
              id="isDefault"
              className="w-4 h-4 rounded text-neutral-900 focus:ring-0 cursor-pointer"
              {...register('isDefault')}
            />
            <label htmlFor="isDefault" className="text-xs font-medium text-neutral-700 cursor-pointer">
              Jadikan wallpaper default untuk obrolan baru
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
              isLoading={createWallpaper.isPending || mediaUpload.isPending}
            >
              Simpan Wallpaper
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
