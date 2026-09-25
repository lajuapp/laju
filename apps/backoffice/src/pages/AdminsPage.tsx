import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  ShieldCheck,
  UserPlus,
  Trash2,
  CheckCircle,
  XCircle,
  AlertCircle,
  Lock,
} from 'lucide-react';
import {
  useAdminsList,
  useAdminRoles,
  useCreateAdmin,
  useUpdateAdmin,
  useDeleteAdmin,
} from '../hooks/useAdmins';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';

const createAdminSchema = z.object({
  name: z.string().min(2, 'Nama minimal 2 karakter'),
  username: z
    .string()
    .min(3, 'Username minimal 3 karakter')
    .regex(/^[a-zA-Z0-9_]+$/, 'Hanya huruf, angka, dan underscore'),
  email: z.string().email('Format email tidak valid'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
  roleId: z.string().min(1, 'Role harus dipilih'),
});

type CreateAdminFormData = z.infer<typeof createAdminSchema>;

export function AdminsPage() {
  const { data: admins, isLoading } = useAdminsList();
  const { data: roles } = useAdminRoles();
  const createAdmin = useCreateAdmin();
  const updateAdmin = useUpdateAdmin();
  const deleteAdmin = useDeleteAdmin();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<CreateAdminFormData>({
    resolver: zodResolver(createAdminSchema),
  });

  const onSubmit = (data: CreateAdminFormData) => {
    setErrorMessage(null);
    createAdmin.mutate(data, {
      onSuccess: () => {
        setIsModalOpen(false);
        reset();
      },
      onError: (err: any) => {
        setErrorMessage(
          err.response?.data?.message || 'Gagal menambahkan admin baru'
        );
      },
    });
  };

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    updateAdmin.mutate({ id, isActive: !currentStatus });
  };

  const handleDelete = (id: string, username: string) => {
    if (confirm(`Yakin ingin menghapus admin "${username}"?`)) {
      deleteAdmin.mutate(id);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Manajemen Tim Admin (Backoffice Users)
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Kelola akun pengguna backoffice, penetapan role wewenang, dan status akses sistem
          </p>
        </div>

        <Button
          variant="primary"
          icon={<UserPlus className="w-4 h-4" />}
          onClick={() => {
            setErrorMessage(null);
            setIsModalOpen(true);
          }}
        >
          Tambah Admin Baru
        </Button>
      </div>

      {/* Admins Table Card */}
      <div className="bg-white rounded-2xl border border-neutral-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-neutral-50/70 border-b border-neutral-100 text-neutral-500 uppercase tracking-wider text-[10px] font-bold">
              <tr>
                <th className="px-5 py-3.5">Admin</th>
                <th className="px-5 py-3.5">Email</th>
                <th className="px-5 py-3.5">Role Akses</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Dibuat Pada</th>
                <th className="px-5 py-3.5 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Memuat data tim admin...
                  </td>
                </tr>
              ) : admins && admins.length > 0 ? (
                admins.map((adm) => (
                  <tr key={adm.id} className="hover:bg-neutral-50/50 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className="w-7 h-7 rounded-lg bg-neutral-100 text-neutral-700 flex items-center justify-center font-bold text-xs">
                          {adm.name.substring(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-neutral-900">{adm.name}</div>
                          <div className="text-[11px] text-neutral-400 font-mono">@{adm.username}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-3.5 font-mono text-[11px] text-neutral-600">
                      {adm.email}
                    </td>
                    <td className="px-5 py-3.5">
                      <Badge variant="brand">
                        {typeof adm.role === 'string' ? adm.role : (adm.role as any)?.name || 'Admin'}
                      </Badge>
                    </td>
                    <td className="px-5 py-3.5">
                      {adm.isActive ? (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700">
                          <CheckCircle className="w-3.5 h-3.5 text-emerald-500" />
                          Aktif
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-rose-700">
                          <XCircle className="w-3.5 h-3.5 text-rose-500" />
                          Nonaktif
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(adm.createdAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-5 py-3.5 text-right space-x-2">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleToggleActive(adm.id, adm.isActive)}
                      >
                        {adm.isActive ? 'Nonaktifkan' : 'Aktifkan'}
                      </Button>
                      {adm.username !== 'admin' && (
                        <Button
                          size="sm"
                          variant="ghost"
                          className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                          onClick={() => handleDelete(adm.id, adm.username)}
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </Button>
                      )}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Belum ada admin terdaftar
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Admin Modal with Zod Form */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Tambah Admin Backoffice Baru"
        description="Buat akun admin baru dengan hak akses dan peran yang sesuai"
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-3.5">
          <Input
            label="Nama Lengkap"
            placeholder="Misal: John Doe"
            error={errors.name?.message}
            {...register('name')}
          />

          <Input
            label="Username"
            placeholder="johndoe (huruf kecil & angka)"
            error={errors.username?.message}
            {...register('username')}
          />

          <Input
            label="Alamat Email"
            type="email"
            placeholder="john@laju.chat"
            error={errors.email?.message}
            {...register('email')}
          />

          <Input
            label="Kata Sandi Awal"
            type="password"
            placeholder="Minimal 6 karakter"
            error={errors.password?.message}
            {...register('password')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Role Wewenang
            </label>
            <select
              className="w-full px-3 py-2 text-xs rounded-xl border border-neutral-200 bg-white text-neutral-900 focus:outline-none focus:border-neutral-900"
              {...register('roleId')}
            >
              <option value="">-- Pilih Role Admin --</option>
              {roles?.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name} ({r.description || 'Standar'})
                </option>
              ))}
            </select>
            {errors.roleId && (
              <p className="text-[11px] text-rose-600 font-medium">
                {errors.roleId.message}
              </p>
            )}
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
              isLoading={createAdmin.isPending}
            >
              Simpan Admin Baru
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
