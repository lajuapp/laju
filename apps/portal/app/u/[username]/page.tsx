import type { Metadata } from 'next';
import { SmartRedirector } from '@/components/deeplink/SmartRedirector';

interface UserPageProps {
  params: {
    username: string;
  };
}

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: UserPageProps): Promise<Metadata> {
  const username = params.username.startsWith('@') ? params.username : `@${params.username}`;

  return {
    title: `Hubungi ${username} di LAJU`,
    description: `Kirim pesan terenkripsi end-to-end atau lakukan panggilan video langsung ke ${username} di LAJU Messenger.`,
    openGraph: {
      title: `Hubungi ${username} di LAJU`,
      description: `Kirim pesan terenkripsi atau lakukan panggilan video langsung ke ${username}.`,
    },
  };
}

export default function UserPage({ params }: UserPageProps) {
  const username = params.username.startsWith('@') ? params.username : `@${params.username}`;

  return (
    <div className="min-h-[80vh] flex items-center justify-center radial-gradient-bg">
      <SmartRedirector
        type="user"
        code={params.username}
        title={username}
        subtitle="Mulai obrolan terenkripsi atau panggilan langsung dengan pengguna ini di aplikasi LAJU."
      />
    </div>
  );
}
