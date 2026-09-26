import { Check, X, Sparkles, Star, ThumbsUp, Heart, ShieldCheck } from 'lucide-react';

const comparisons = [
  {
    feature: 'Iklan & Banner Promosi',
    other: 'Sering muncul iklan dan pesan sponsor mengganggu',
    laju: '100% Bersih & Bebas Iklan Selamanya',
    isPositive: true,
  },
  {
    feature: 'Kecepatan & Beban Memori',
    other: 'Makin lama makin berat dan bikin HP lambat',
    laju: 'Super Ringan & Lancar di Segala Tipe HP',
    isPositive: true,
  },
  {
    feature: 'Kualitas Foto & Video',
    other: 'Dikompres hingga buram dan pecah',
    laju: 'Kualitas Asli Tajam Tanpa Rusak',
    isPositive: true,
  },
  {
    feature: 'Panggilan Telepon & Video Call',
    other: 'Sering delay atau suara putus-putus',
    laju: 'Koneksi Langsung Jernih Tanpa Jeda',
    isPositive: true,
  },
  {
    feature: 'Kerahasiaan Obrolan',
    other: 'Data sering dipakai untuk penargetan iklan',
    laju: 'Murni Rahasia Milik Kamu & Penerima',
    isPositive: true,
  },
];

const testimonials = [
  {
    name: 'Dimas Prasetyo',
    role: 'Pengguna Harian • Jakarta',
    comment: 'Paling kerasa bedanya itu ringan banget. Buka chat gak pake loading, dan yang paling kusuka gak ada iklan berseliweran sama sekali!',
  },
  {
    name: 'Sarah Melinda',
    role: 'Mahasiswi • Bandung',
    comment: 'Sering video call sama keluarga di kampung, suaranya jernih banget dan gak delay meski sinyal pas-pasan. Hemat baterai juga.',
  },
  {
    name: 'Budi Santoso',
    role: 'Wiraswasta • Surabaya',
    comment: 'Kirim foto dagangan dan dokumen PDF kerjaan kualitasnya tetap tajam tanpa pecah. Bikin komunikasi sama tim jadi jauh lebih gampang.',
  },
];

export function SecuritySection() {
  return (
    <section id="why-laju" className="py-20 sm:py-28 bg-white border-t border-slate-100 relative">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-1.5 text-xs font-bold text-emerald-800 bg-emerald-50 border border-emerald-200 px-3.5 py-1 rounded-full uppercase tracking-wider mb-4">
            <ThumbsUp className="h-3.5 w-3.5 text-emerald-600" />
            <span>Alasan Beralih</span>
          </div>
          <h2 className="text-3xl sm:text-5xl font-extrabold text-slate-900 tracking-tight leading-tight">
            Kenapa Banyak Orang Mulai <span className="text-emerald-600">Pindah ke LAJU?</span>
          </h2>
          <p className="mt-4 text-slate-600 text-base sm:text-lg leading-relaxed">
            Bandingkan sendiri perbedaannya. Nikmati standar baru aplikasi berkirim pesan yang mengutamakan kenyamanan penggunanya.
          </p>
        </div>

        {/* Comparison Table */}
        <div className="mx-auto max-w-4xl rounded-[2.5rem] border border-slate-200/90 bg-white shadow-xl soft-shadow overflow-hidden mb-20">
          <div className="grid grid-cols-12 bg-slate-50 border-b border-slate-200 text-left p-4 sm:p-6 text-xs sm:text-sm font-bold text-slate-700">
            <div className="col-span-4 sm:col-span-4 text-slate-900">Fitur & Pengalaman</div>
            <div className="col-span-4 sm:col-span-4 text-slate-500">Aplikasi Chat Lain</div>
            <div className="col-span-4 sm:col-span-4 text-emerald-700 font-extrabold flex items-center gap-1.5">
              <Sparkles className="h-4 w-4 text-emerald-600" />
              <span>LAJU Messenger</span>
            </div>
          </div>

          <div className="divide-y divide-slate-100 text-left text-xs sm:text-sm">
            {comparisons.map((item, idx) => (
              <div key={idx} className="grid grid-cols-12 p-4 sm:p-6 items-center hover:bg-slate-50/50 transition-colors">
                <div className="col-span-4 sm:col-span-4 font-bold text-slate-900 pr-2">
                  {item.feature}
                </div>
                <div className="col-span-4 sm:col-span-4 text-slate-500 flex items-center gap-1.5 pr-2">
                  <X className="h-4 w-4 text-rose-500 shrink-0" />
                  <span className="hidden sm:inline">{item.other}</span>
                  <span className="sm:hidden text-[11px] leading-tight">{item.other}</span>
                </div>
                <div className="col-span-4 sm:col-span-4 font-semibold text-emerald-800 flex items-center gap-1.5">
                  <Check className="h-4 w-4 text-emerald-600 shrink-0" />
                  <span className="hidden sm:inline">{item.laju}</span>
                  <span className="sm:hidden text-[11px] leading-tight font-bold">{item.laju}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* User Testimonials / Social Proof */}
        <div>
          <div className="text-center mb-10">
            <h3 className="text-2xl font-extrabold text-slate-900">Kata Mereka yang Sudah Mencoba</h3>
            <p className="text-sm text-slate-500 mt-1">Pengalaman nyata dari mereka yang menggunakan LAJU setiap hari.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-left">
            {testimonials.map((item, idx) => (
              <div
                key={idx}
                className="rounded-3xl border border-slate-200/80 bg-slate-50/60 p-6 sm:p-7 shadow-sm hover:shadow-md hover:bg-white hover:border-emerald-200 transition-all flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center gap-1 text-amber-400 mb-4">
                    {[...Array(5)].map((_, i) => (
                      <Star key={i} className="h-4 w-4 fill-amber-400" />
                    ))}
                  </div>
                  <p className="text-sm text-slate-700 leading-relaxed italic">
                    "{item.comment}"
                  </p>
                </div>

                <div className="mt-6 pt-4 border-t border-slate-200/60">
                  <div className="font-bold text-slate-900 text-sm">{item.name}</div>
                  <div className="text-xs text-slate-500 mt-0.5">{item.role}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
