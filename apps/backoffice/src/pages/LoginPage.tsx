import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, AlertCircle } from 'lucide-react';
import { useLogin } from '../hooks/useAdminAuth';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';

const loginSchema = z.object({
  identifier: z.string().min(1, 'Username atau email harus diisi'),
  password: z.string().min(6, 'Password minimal 6 karakter'),
});

type LoginFormData = z.infer<typeof loginSchema>;

export function LoginPage() {
  const navigate = useNavigate();
  const login = useLogin();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      identifier: '',
      password: '',
    },
  });

  const onSubmit = (data: LoginFormData) => {
    setErrorMessage(null);
    login.mutate(data, {
      onSuccess: () => {
        navigate('/');
      },
      onError: (err: any) => {
        setErrorMessage(
          err.response?.data?.message || 'Login gagal. Periksa kembali kredensial Anda.'
        );
      },
    });
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col justify-center items-center p-4 selection:bg-neutral-200">
      {/* Container Card */}
      <div className="w-full max-w-sm">
        {/* Brand Logo & Title */}
        <div className="text-center mb-8">
          <div className="w-12 h-12 rounded-2xl bg-neutral-900 text-white mx-auto flex items-center justify-center font-black text-xl tracking-tight shadow-md mb-3">
            LJ
          </div>
          <h1 className="text-xl font-extrabold tracking-tight text-neutral-900">
            LAJU Backoffice
          </h1>
          <p className="text-xs text-neutral-500 mt-1">
            Masuk untuk mengakses portal kontrol administrasi
          </p>
        </div>

        {/* Login White Card */}
        <div className="bg-white rounded-2xl border border-neutral-200/80 p-7 shadow-sm">
          {errorMessage && (
            <div className="mb-5 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-start gap-2.5">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
              <span>{errorMessage}</span>
            </div>
          )}

          <form onSubmit={handleSubmit(onSubmit)} autoComplete="off" className="space-y-4">
            <Input
              label="Username atau Email Admin"
              placeholder="Masukkan username atau email"
              autoComplete="username"
              error={errors.identifier?.message}
              {...register('identifier')}
            />

            <Input
              label="Kata Sandi (Password)"
              type="password"
              placeholder="••••••••"
              autoComplete="current-password"
              error={errors.password?.message}
              {...register('password')}
            />

            <Button
              type="submit"
              variant="primary"
              size="lg"
              className="w-full mt-2"
              isLoading={login.isPending}
            >
              Masuk ke Backoffice
            </Button>
          </form>
        </div>

        {/* Security Note */}
        <div className="mt-6 text-center">
          <p className="text-[11px] text-neutral-400 flex items-center justify-center gap-1.5 font-medium">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
            Portal Administrasi Aman & Terproteksi
          </p>
        </div>
      </div>
    </div>
  );
}
