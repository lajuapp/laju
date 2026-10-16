# Zero-Downtime Deployment Guide (Coolify & Traefik)

Panduan konfigurasi untuk memastikan pembaruan aplikasi LAJU (API, Portal, Backoffice) berjalan dengan **Zero-Downtime Deployment** tanpa putus koneksi atau error 502 Bad Gateway saat proses rilis/update di **Coolify** dan **Traefik**.

---

## 1. Prinsip Utama Zero-Downtime di Traefik & Coolify

Agar Traefik dapat mengalihkan trafik tanpa downtime saat kontainer diperbarui, sistem membutuhkan 4 syarat mutlak:

1. **`start-first` Rolling Update Order**:
   Kontainer baru dijalankan terlebih dahulu dan harus mencapai status **`healthy`** sebelum kontainer lama dihentikan.
2. **Tidak Ada Konflik Port Host (`ports:` vs `expose:`)**:
   Hindari mapping port host seperti `ports: ["3000:3000"]`. Dua kontainer tidak bisa mendengarkan port host yang sama secara bersamaan. Gunakan `expose:` dan biarkan Traefik berkomunikasi melalui internal Docker network.
3. **Tidak Ada `container_name:` Statis**:
   Nama kontainer statis seperti `container_name: laju-portal` mencegah Docker membuat kontainer kedua saat *rolling update*. Docker Compose harus diberi kebebasan memberi nama instans.
4. **Healthcheck Aktif pada Level Docker & Traefik Loadbalancer**:
   Traefik memonitor health endpoint. Kontainer baru tidak akan menerima trafik publik sebelum lulus healthcheck HTTP (`200 OK`).

---

## 2. Pengaturan di Coolify Dashboard UI

Saat menambahkan atau mengelola service LAJU di Coolify:

### A. Aktifkan Opsi "Zero Downtime Deployment"
1. Buka Coolify > Project > **Application / Compose Service**.
2. Masuk ke tab **Configuration** > **General**.
3. Pastikan toggle **"Zero Downtime Deployment"** dalam posisi **ON (Aktif)**.

### B. Konfigurasi Health Check di Coolify (Jika Deploy Per-Aplikasi)
Jika Anda mendeploy setiap aplikasi secara terpisah di Coolify (bukan 1 file Compose penuh):
- **API (`api`)**:
  - Health Check Path: `/health`
  - Health Check Interval: `5` detik
  - Health Check Timeout: `3` detik
  - Health Check Retries: `5`
  - Health Check Start Period: `20` detik (memberi waktu migrasi Prisma selesai)
- **Portal (`portal`)**:
  - Health Check Path: `/`
  - Health Check Interval: `5` detik
  - Health Check Timeout: `3` detik
  - Health Check Retries: `5`
  - Health Check Start Period: `15` detik
- **Backoffice Console (`backoffice`)**:
  - Health Check Path: `/`
  - Health Check Interval: `5` detik
  - Health Check Timeout: `3` detik
  - Health Check Retries: `5`
  - Health Check Start Period: `5` detik

### C. Docker Network Traefik & Compose Network
Pada `docker-compose.yml`, service `api`, `portal`, dan `backoffice` terhubung ke dua network internal: `internal` (network terisolasi untuk akses database PostgreSQL, Redis, Gotify, SeaweedFS) dan `edge` (network untuk routing Traefik/Coolify).
Coolify secara otomatis mengintegrasikan proxy Traefik ke port yang di-expose oleh service publik tanpa memerlukan intervensi manual pada nama network external.

### D. Keamanan Data Produksi (Data Persistence Guarantee)
Konfigurasi Zero-Downtime ini murni mengatur alur *rolling update* dan perutean proxy Traefik pada level reverse proxy:
- Volume penyimpanan database (`postgres_data`, `redis_data`, `gotify_data`, `seaweedfs_*`, `admin_media_data`) **100% aman dan tidak tersentuh**.
- Data produksi, riwayat chat, media, dan pengguna tetap tersimpan utuh di persistent storage host.

---

## 3. Graceful Shutdown & WebSocket Draining

Service NestJS (`api`) telah dilengkapi:
- `app.enableShutdownHooks();` di `src/main.ts`.
- `stop_grace_period: 25s` di `docker-compose.yml`.

Saat kontainer lama menerima sinyal `SIGTERM`:
1. Traefik langsung berhenti mengarahkan request HTTP baru ke kontainer lama.
2. Kontainer lama memiliki jendela waktu 25 detik untuk menyelesaikan request HTTP in-flight dan menutup koneksi WebSocket/SSE secara aman.
3. Aplikasi mobile/web otomatis melakukan reconnect instan ke kontainer baru yang sudah berstatus `healthy`.
