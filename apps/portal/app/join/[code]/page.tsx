import type { Metadata } from 'next';
import { SmartRedirector } from '@/components/deeplink/SmartRedirector';

interface JoinPageProps {
  params: {
    code: string;
  };
}

export const dynamic = 'force-dynamic';

async function getGroupInviteInfo(code: string) {
  try {
    const raw = (process.env.INTERNAL_API_URL || process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000').trim();
    const apiUrl = raw.startsWith('http://') || raw.startsWith('https://') ? raw.replace(/\/+$/, '') : `https://${raw.replace(/\/+$/, '')}`;

    const res = await fetch(`${apiUrl}/conversations/invite/${encodeURIComponent(code)}/info`, {
      cache: 'no-store',
    });

    if (res.ok) {
      const data = await res.json();
      return data;
    }
  } catch (_) {
    // Backend offline or invite code invalid
  }
  return null;
}

export async function generateMetadata({ params }: JoinPageProps): Promise<Metadata> {
  const info = await getGroupInviteInfo(params.code);
  const groupTitle = info?.title || `Undangan Grup LAJU`;
  const description = info?.description
    ? `${info.description} • Bergabung dengan obrolan terenkripsi di LAJU.`
    : info?.memberCount
    ? `${info.memberCount} Anggota • Bergabung dengan percakapan terenkripsi di LAJU.`
    : 'Buka tautan ini untuk bergabung ke dalam percakapan grup LAJU Secure Messenger.';

  const avatar = info?.avatarUrl || '/images/og-default.png';

  return {
    title: `${groupTitle} | LAJU Messenger`,
    description,
    openGraph: {
      title: `${groupTitle} | LAJU Messenger`,
      description,
      images: [avatar],
      type: 'website',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${groupTitle} | LAJU Messenger`,
      description,
      images: [avatar],
    },
  };
}

export default async function JoinPage({ params }: JoinPageProps) {
  const info = await getGroupInviteInfo(params.code);

  return (
    <div className="min-h-[80vh] flex items-center justify-center radial-gradient-bg">
      <SmartRedirector
        type="group"
        code={params.code}
        title={info?.title || 'Undangan Grup LAJU'}
        subtitle={info?.description || 'Ketuk tombol di bawah untuk bergabung langsung ke obrolan grup ini.'}
        memberCount={info?.memberCount}
        avatarUrl={info?.avatarUrl}
      />
    </div>
  );
}
