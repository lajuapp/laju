import type { Metadata } from 'next';
import './globals.css';
import { Navbar } from '@/components/landing/Navbar';
import { Footer } from '@/components/landing/Footer';
import { LanguageProvider } from '@/context/LanguageContext';

function getSafeAppUrl(): URL {
  const raw = (process.env.NEXT_PUBLIC_APP_URL || '').trim();
  if (raw) {
    const formatted = raw.startsWith('http://') || raw.startsWith('https://') ? raw : `https://${raw}`;
    try {
      return new URL(formatted);
    } catch (_) {}
  }
  return new URL('https://laju.chat');
}

const safeAppUrl = getSafeAppUrl();

export const metadata: Metadata = {
  title: 'LAJU Messenger | Ruang Obrolan Aman & Privasi Terjaga',
  description:
    'Aplikasi pesan instan dan panggilan suara/video jernih dengan privasi penuh, terenkripsi end-to-end langsung dari HP kamu, bebas iklan, dan ringan.',
  metadataBase: safeAppUrl,
  openGraph: {
    title: 'LAJU Messenger | Ruang Obrolan Aman & Privasi Terjaga',
    description:
      'Aplikasi pesan instan dan panggilan suara/video jernih dengan privasi penuh, terenkripsi end-to-end langsung dari HP kamu, bebas iklan, dan ringan.',
    url: safeAppUrl.toString(),
    siteName: 'LAJU Messenger',
    locale: 'id_ID',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'LAJU Messenger | Ruang Obrolan Aman & Privasi Terjaga',
    description:
      'Aplikasi pesan instan dan panggilan suara/video jernih dengan privasi penuh, terenkripsi end-to-end langsung dari HP kamu, bebas iklan, dan ringan.',
  },
  icons: {
    icon: '/images/logo_icon.png',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id" className="scroll-smooth">
      <body className="min-h-screen flex flex-col bg-[#F8FAFC] text-slate-900 antialiased selection:bg-laju-500 selection:text-slate-950">
        <LanguageProvider>
          <Navbar />
          <main className="flex-1">{children}</main>
          <Footer />
        </LanguageProvider>
      </body>
    </html>
  );
}
