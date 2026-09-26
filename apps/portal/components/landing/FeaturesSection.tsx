import { 
  ShieldCheck, 
  Video, 
  MessageSquare, 
  Users, 
  Clock, 
  EyeOff, 
  BellRing, 
  Smartphone 
} from 'lucide-react';

const features = [
  {
    icon: ShieldCheck,
    title: 'Enkripsi End-to-End Penuh',
    description: 'Semua pesan teks, media gambar, video, dan dokumen dienkripsi langsung di perangkat pengirim dan hanya dapat didekripsi oleh penerima yang dituju.',
  },
  {
    icon: Video,
    title: 'Panggilan Video & Suara WebRTC P2P',
    description: 'Panggilan peer-to-peer berkualitas tinggi dengan kompresi bitrate adaptif, tanpa lag, hemat bandwidth, dan privasi audio terjaga sepenuhnya.',
  },
  {
    icon: Users,
    title: 'Grup Kolaborasi Skala Besar',
    description: 'Buat grup komunitas atau tim dengan ribuan anggota, manajemen hak admin lengkap, dan undangan tautan yang terlindungi.',
  },
  {
    icon: Clock,
    title: 'Pesan Menghilang Otomatis',
    description: 'Atur batas waktu kedaluwarsa pesan (disappearing messages) untuk melindungi obrolan rahasia dari jejak digital yang tidak diinginkan.',
  },
  {
    icon: BellRing,
    title: 'Push Notifikasi Cerdas & Andal',
    description: 'Layanan latar belakang cerdas yang memastikan panggilan dan pesan masuk seketika bahkan saat aplikasi sedang ditutup dari daftar Recent Apps.',
  },
  {
    icon: EyeOff,
    title: 'Tanpa Pelacak & Profiling',
    description: 'Kami tidak menjual data Anda, tidak menanamkan tracker analitik pihak ketiga, dan tidak pernah menyimpan metadata obrolan untuk profiling iklan.',
  },
];

export function FeaturesSection() {
  return (
    <section id="features" className="py-24 bg-slate-950/60 border-t border-white/5 relative">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h2 className="text-xs font-bold text-brand-400 uppercase tracking-widest mb-3">
            Fitur Unggulan
          </h2>
          <p className="text-3xl sm:text-4xl font-black text-white tracking-tight">
            Dirancang untuk Kecepatan, Kenyamanan, dan Kedaulatan Privasi
          </p>
          <p className="mt-4 text-slate-400 text-sm sm:text-base">
            Nikmati pengalaman berkirim pesan tanpa gangguan, dirancang dengan teknologi enkripsi modern dan protokol komunikasi terdepan.
          </p>
        </div>

        {/* Feature Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((item, idx) => (
            <div
              key={idx}
              className="p-6 rounded-2xl bg-white/[0.03] border border-white/5 hover:border-brand-500/30 hover:bg-white/[0.06] transition-all group"
            >
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-500/10 text-brand-400 mb-5 group-hover:scale-110 group-hover:bg-brand-500/20 transition-all">
                <item.icon className="h-6 w-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">{item.title}</h3>
              <p className="text-sm text-slate-400 leading-relaxed">{item.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
