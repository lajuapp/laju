import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  UserPlus,
  Trash2,
  CheckCircle,
  XCircle,
  AlertCircle,
  Key,
  Edit3,
  Copy,
  Check,
  Eye,
  EyeOff,
  Sparkles,
  ShieldAlert,
} from 'lucide-react';
import {
  useAdminsList,
  useAdminRoles,
  useCreateAdmin,
  useUpdateAdmin,
  useDeleteAdmin,
  useResetAdminPassword,
} from '../hooks/useAdmins';
import { Button } from '../components/ui/Button';
import { Modal } from '../components/ui/Modal';
import { ConfirmModal } from '../components/ui/ConfirmModal';
import { Input } from '../components/ui/Input';
import { Badge } from '../components/ui/Badge';
import { Pagination } from '../components/ui/Pagination';
import { usePagination } from '../hooks/usePagination';
import { AdminUser } from '../api/types';

const createAdminSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  username: z
    .string()
    .min(3, 'Username must be at least 3 characters')
    .regex(/^[a-zA-Z0-9_]+$/, 'Only letters, numbers, and underscore allowed'),
  email: z.string().email('Invalid email address format'),
  password: z.string().min(6, 'Password must be at least 6 characters'),
  roleId: z.string().min(1, 'Role must be selected'),
});

type CreateAdminFormData = z.infer<typeof createAdminSchema>;

const editAdminSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  username: z
    .string()
    .min(3, 'Username must be at least 3 characters')
    .regex(/^[a-zA-Z0-9_]+$/, 'Only letters, numbers, and underscore allowed'),
  email: z.string().email('Invalid email address format'),
  roleId: z.string().min(1, 'Role must be selected'),
});

type EditAdminFormData = z.infer<typeof editAdminSchema>;

export function AdminsPage() {
  const { data: admins, isLoading } = useAdminsList();
  const { data: roles } = useAdminRoles();
  const createAdmin = useCreateAdmin();
  const updateAdmin = useUpdateAdmin();
  const deleteAdmin = useDeleteAdmin();
  const resetPassword = useResetAdminPassword();

  const pagination = usePagination(admins || [], { initialPageSize: 10 });

  // Add Admin Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Edit Admin Modal
  const [editAdmin, setEditAdmin] = useState<AdminUser | null>(null);
  const [editErrorMessage, setEditErrorMessage] = useState<string | null>(null);

  // Reset Password Modal
  const [resetModalAdmin, setResetModalAdmin] = useState<AdminUser | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [copied, setCopied] = useState(false);
  const [resetError, setResetError] = useState<string | null>(null);
  const [resetSuccess, setResetSuccess] = useState<string | null>(null);

  // Delete Admin Modal
  const [deleteModal, setDeleteModal] = useState<{
    isOpen: boolean;
    adminId: string;
    username: string;
  }>({ isOpen: false, adminId: '', username: '' });

  const {
    register: registerCreate,
    handleSubmit: handleSubmitCreate,
    reset: resetCreate,
    formState: { errors: errorsCreate },
  } = useForm<CreateAdminFormData>({
    resolver: zodResolver(createAdminSchema),
  });

  const {
    register: registerEdit,
    handleSubmit: handleSubmitEdit,
    reset: resetEdit,
    setValue: setEditValue,
    formState: { errors: errorsEdit },
  } = useForm<EditAdminFormData>({
    resolver: zodResolver(editAdminSchema),
  });

  const handleOpenEdit = (admin: AdminUser) => {
    setEditAdmin(admin);
    setEditErrorMessage(null);
    setEditValue('name', admin.name);
    setEditValue('username', admin.username);
    setEditValue('email', admin.email);
    setEditValue('roleId', admin.roleId || (typeof admin.role === 'object' ? (admin.role as any)?.id : ''));
  };

  const handleOpenReset = (admin: AdminUser) => {
    setResetModalAdmin(admin);
    setNewPassword('');
    setConfirmPassword('');
    setShowPassword(false);
    setCopied(false);
    setResetError(null);
    setResetSuccess(null);
  };

  const handleGeneratePassword = () => {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*';
    let generated = '';
    for (let i = 0; i < 14; i++) {
      generated += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setNewPassword(generated);
    setConfirmPassword(generated);
    setShowPassword(true);

    navigator.clipboard.writeText(generated).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 3000);
    });
  };

  const handleConfirmResetPassword = (e: React.FormEvent) => {
    e.preventDefault();
    setResetError(null);
    setResetSuccess(null);

    if (!resetModalAdmin) return;

    if (!newPassword || newPassword.length < 6) {
      setResetError('Password baru minimal 6 karakter');
      return;
    }

    if (newPassword !== confirmPassword) {
      setResetError('Konfirmasi password tidak cocok');
      return;
    }

    resetPassword.mutate(
      { id: resetModalAdmin.id, newPassword },
      {
        onSuccess: (res: any) => {
          setResetSuccess(res?.message || 'Password berhasil di-reset.');
          setTimeout(() => {
            setResetModalAdmin(null);
          }, 1500);
        },
        onError: (err: any) => {
          setResetError(
            err.response?.data?.message || 'Gagal mereset password administrator'
          );
        },
      }
    );
  };

  const onSubmitCreate = (data: CreateAdminFormData) => {
    setErrorMessage(null);
    createAdmin.mutate(data, {
      onSuccess: () => {
        setIsModalOpen(false);
        resetCreate();
      },
      onError: (err: any) => {
        setErrorMessage(
          err.response?.data?.message || 'Failed to add new administrator'
        );
      },
    });
  };

  const onSubmitEdit = (data: EditAdminFormData) => {
    if (!editAdmin) return;
    setEditErrorMessage(null);
    updateAdmin.mutate(
      { id: editAdmin.id, ...data },
      {
        onSuccess: () => {
          setEditAdmin(null);
          resetEdit();
        },
        onError: (err: any) => {
          setEditErrorMessage(
            err.response?.data?.message || 'Failed to update administrator'
          );
        },
      }
    );
  };

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    updateAdmin.mutate({ id, isActive: !currentStatus });
  };

  const handleOpenDelete = (id: string, username: string) => {
    setDeleteModal({ isOpen: true, adminId: id, username });
  };

  const handleConfirmDelete = () => {
    deleteAdmin.mutate(deleteModal.adminId, {
      onSuccess: () => {
        setDeleteModal({ isOpen: false, adminId: '', username: '' });
      },
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            Admin Team Management
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Manage console administrators, role privileges, access keys, and system states.
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
          Add New Admin
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
                <th className="px-5 py-3.5">Assigned Role</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Created At</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100">
              {isLoading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-neutral-400">
                    Loading admin team...
                  </td>
                </tr>
              ) : pagination.paginatedItems && pagination.paginatedItems.length > 0 ? (
                pagination.paginatedItems.map((adm) => (
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
                          Active
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-rose-700">
                          <XCircle className="w-3.5 h-3.5 text-rose-500" />
                          Inactive
                        </span>
                      )}
                    </td>
                    <td className="px-5 py-3.5 text-neutral-500 text-[11px]">
                      {new Date(adm.createdAt).toLocaleDateString('en-US', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td className="px-5 py-3.5 text-right space-x-1.5 whitespace-nowrap">
                      {/* Edit Admin Button */}
                      <Button
                        size="sm"
                        variant="ghost"
                        icon={<Edit3 className="w-3.5 h-3.5 text-neutral-600" />}
                        onClick={() => handleOpenEdit(adm)}
                        title="Edit Admin Information"
                      >
                        Edit
                      </Button>

                      {/* Reset Password Button */}
                      <Button
                        size="sm"
                        variant="outline"
                        icon={<Key className="w-3.5 h-3.5 text-amber-600" />}
                        onClick={() => handleOpenReset(adm)}
                        title="Reset Account Password"
                        className="hover:border-amber-300 hover:bg-amber-50/50"
                      >
                        Reset Password
                      </Button>

                      {/* Activate / Deactivate Toggle */}
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleToggleActive(adm.id, adm.isActive)}
                      >
                        {adm.isActive ? 'Deactivate' : 'Activate'}
                      </Button>

                      {/* Delete Admin */}
                      {adm.username !== 'admin' && (
                        <Button
                          size="sm"
                          variant="ghost"
                          className="text-rose-600 hover:text-rose-700 hover:bg-rose-50"
                          onClick={() => handleOpenDelete(adm.id, adm.username)}
                          title="Remove Admin Account"
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
                    No administrators registered
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

      {/* Add Admin Modal */}
      <Modal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        title="Add New Backoffice Administrator"
        description="Create an administrative account with designated authorization privileges."
      >
        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmitCreate(onSubmitCreate)} className="space-y-3.5">
          <Input
            label="Full Name"
            placeholder="e.g. John Doe"
            error={errorsCreate.name?.message}
            {...registerCreate('name')}
          />

          <Input
            label="Username"
            placeholder="johndoe (alphanumeric)"
            error={errorsCreate.username?.message}
            {...registerCreate('username')}
          />

          <Input
            label="Email Address"
            type="email"
            placeholder="john@laju.chat"
            error={errorsCreate.email?.message}
            {...registerCreate('email')}
          />

          <Input
            label="Initial Password"
            type="password"
            placeholder="At least 6 characters"
            error={errorsCreate.password?.message}
            {...registerCreate('password')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Privilege Role
            </label>
            <select
              className="w-full px-3 py-2 text-xs rounded-xl border border-neutral-200 bg-white text-neutral-900 focus:outline-none focus:border-neutral-900"
              {...registerCreate('roleId')}
            >
              <option value="">-- Select Admin Role --</option>
              {roles?.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name} ({r.description || 'Standard'})
                </option>
              ))}
            </select>
            {errorsCreate.roleId && (
              <p className="text-[11px] text-rose-600 font-medium">
                {errorsCreate.roleId.message}
              </p>
            )}
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={createAdmin.isPending}
            >
              Save New Admin
            </Button>
          </div>
        </form>
      </Modal>

      {/* Edit Admin Modal */}
      <Modal
        isOpen={!!editAdmin}
        onClose={() => setEditAdmin(null)}
        title="Edit Administrator Details"
        description={`Update account profile and privilege roles for "${editAdmin?.username}".`}
      >
        {editErrorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{editErrorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmitEdit(onSubmitEdit)} className="space-y-3.5">
          <Input
            label="Full Name"
            placeholder="e.g. John Doe"
            error={errorsEdit.name?.message}
            {...registerEdit('name')}
          />

          <Input
            label="Username"
            placeholder="johndoe (alphanumeric)"
            error={errorsEdit.username?.message}
            {...registerEdit('username')}
          />

          <Input
            label="Email Address"
            type="email"
            placeholder="john@laju.chat"
            error={errorsEdit.email?.message}
            {...registerEdit('email')}
          />

          <div className="space-y-1.5">
            <label className="block text-xs font-semibold text-neutral-700">
              Privilege Role
            </label>
            <select
              className="w-full px-3 py-2 text-xs rounded-xl border border-neutral-200 bg-white text-neutral-900 focus:outline-none focus:border-neutral-900"
              {...registerEdit('roleId')}
            >
              <option value="">-- Select Admin Role --</option>
              {roles?.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name} ({r.description || 'Standard'})
                </option>
              ))}
            </select>
            {errorsEdit.roleId && (
              <p className="text-[11px] text-rose-600 font-medium">
                {errorsEdit.roleId.message}
              </p>
            )}
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setEditAdmin(null)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={updateAdmin.isPending}
            >
              Save Changes
            </Button>
          </div>
        </form>
      </Modal>

      {/* Reset Password Modal */}
      <Modal
        isOpen={!!resetModalAdmin}
        onClose={() => setResetModalAdmin(null)}
        title="Reset Administrator Password"
        description={`Set a new secure access password for administrator "${resetModalAdmin?.name}" (@${resetModalAdmin?.username}).`}
      >
        {resetError && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{resetError}</span>
          </div>
        )}

        {resetSuccess && (
          <div className="mb-4 p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center gap-2">
            <CheckCircle className="w-4 h-4 flex-shrink-0 text-emerald-600" />
            <span>{resetSuccess}</span>
          </div>
        )}

        {/* Security Warning Notice */}
        <div className="mb-4 p-3 rounded-xl bg-amber-50/80 border border-amber-200/80 text-amber-900 text-xs flex items-start gap-2.5">
          <ShieldAlert className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
          <div className="text-[11px] leading-relaxed">
            <span className="font-bold">Security Notice: </span>
            Resetting this password will immediately invalidate all active login sessions for @{resetModalAdmin?.username}. They will be required to sign in again with the new credentials.
          </div>
        </div>

        <form onSubmit={handleConfirmResetPassword} className="space-y-4">
          <div className="flex items-center justify-between">
            <label className="block text-xs font-semibold text-neutral-700">
              New Password
            </label>
            <button
              type="button"
              onClick={handleGeneratePassword}
              className="text-[11px] font-bold text-brand-700 hover:text-brand-800 flex items-center gap-1.5 px-2 py-1 rounded-lg bg-brand-50 hover:bg-brand-100/80 transition-colors"
            >
              <Sparkles className="w-3.5 h-3.5 text-brand-600" />
              <span>Generate Strong Key</span>
              {copied ? (
                <span className="text-[10px] text-emerald-600 flex items-center gap-0.5 ml-1 font-semibold">
                  <Check className="w-3 h-3" /> Copied!
                </span>
              ) : (
                <Copy className="w-3 h-3 text-neutral-400 ml-0.5" />
              )}
            </button>
          </div>

          <div className="relative">
            <Input
              type={showPassword ? 'text' : 'password'}
              placeholder="Enter or generate new password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className="pr-10 font-mono text-xs"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-2.5 text-neutral-400 hover:text-neutral-700 transition-colors"
              title={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>

          <div>
            <label className="block text-xs font-semibold text-neutral-700 mb-1">
              Confirm New Password
            </label>
            <Input
              type={showPassword ? 'text' : 'password'}
              placeholder="Confirm new password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="font-mono text-xs"
            />
          </div>

          <div className="flex justify-end gap-2 pt-4 border-t border-neutral-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => setResetModalAdmin(null)}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              variant="primary"
              isLoading={resetPassword.isPending}
              icon={<Key className="w-3.5 h-3.5" />}
            >
              Save & Reset Password
            </Button>
          </div>
        </form>
      </Modal>

      {/* Delete Admin Modal */}
      <ConfirmModal
        isOpen={deleteModal.isOpen}
        onClose={() => setDeleteModal({ isOpen: false, adminId: '', username: '' })}
        onConfirm={handleConfirmDelete}
        title="Remove Administrator Account"
        description={`Are you sure you want to remove administrator "${deleteModal.username}"? Backoffice access for this account will be permanently revoked.`}
        confirmText="Remove Admin"
        cancelText="Cancel"
        variant="danger"
        isLoading={deleteAdmin.isPending}
      />
    </div>
  );
}
