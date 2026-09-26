import type { Metadata } from 'next';
import './globals.css';
import { Navbar } from '@/components/landing/Navbar';
import { Footer } from '@/components/landing/Footer';

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
  title: 'LAJU Messenger | Chat Cepat, Ringan & Bebas Iklan',
  description:
    'Aplikasi pesan instan dan panggilan suara/video jernih. Super ringan di HP, hemat kuota, bebas iklan mengganggu, dan privasi kamu terjaga penuh.',
  metadataBase: safeAppUrl,
  openGraph: {
    title: 'LAJU Messenger | Chat Cepat, Ringan & Bebas Iklan',
    description:
      'Aplikasi pesan instan dan panggilan suara/video jernih. Super ringan di HP, hemat kuota, dan bebas iklan mengganggu.',
    url: safeAppUrl.toString(),
    siteName: 'LAJU Messenger',
    locale: 'id_ID',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'LAJU Messenger | Chat Cepat, Ringan & Bebas Iklan',
    description:
      'Aplikasi pesan instan dan panggilan suara/video jernih. Super ringan di HP, hemat kuota, dan bebas iklan mengganggu.',
  },
  icons: {
    icon: '/favicon.ico',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id" className="scroll-smooth">
      <body className="min-h-screen flex flex-col bg-[#F5F4EF] text-slate-900 antialiased selection:bg-pine-800 selection:text-white">
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
