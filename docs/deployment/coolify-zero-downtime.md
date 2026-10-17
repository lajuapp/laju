# Zero-Downtime Deployment Guide (Coolify & Traefik)

Panduan konfigurasi untuk memastikan pembaruan aplikasi LAJU (API, Portal, Backoffice) berjalan dengan **Zero-Downtime Deployment** tanpa putus koneksi, tanpa error 502 Bad Gateway, dan tanpa konflik router Traefik saat proses rilis/update di **Coolify**.

---

## 1. Prinsip Utama Zero-Downtime di Traefik & Coolify

Agar Traefik (`coolify-proxy`) dapat mengalihkan trafik tanpa downtime saat kontainer diperbarui, sistem membutuhkan 4 syarat mutlak:

1. **Tidak Ada Konflik Port Host (`ports:` vs `expose:`)**:
   Hindari mapping port host seperti `ports: ["3000:3000"]`. Dua kontainer tidak bisa mendengarkan port host yang sama secara bersamaan saat *rolling update*. Gunakan `expose:` dan biarkan Traefik berkomunikasi melalui internal Docker network.
2. **Tidak Ada `container_name:` Statis pada Service Aplikasi**:
   Nama kontainer statis seperti `container_name: laju-portal` mencegah Docker membuat kontainer kedua saat *rolling update*. Service `api`, `worker`, `backoffice`, dan `portal` dibiarkan tanpa `container_name:` agar Docker Compose dapat menjalankan kontainer baru berdampingan dengan kontainer lama.
3. **Healthcheck Aktif pada Level Docker (`healthcheck:` di `docker-compose.yml`)**:
   Provider Docker pada Traefik (`coolify-proxy`) **secara otomatis membaca status `HEALTHCHECK` bawaan Docker**. Kontainer baru yang masih berstatus `starting` atau `unhealthy` otomatis ditahan oleh Traefik dan tidak akan menerima trafik publik sampai status Docker-nya berubah menjadi `healthy`.
4. **Jangan Menambahkan Label `traefik.http.services.<nama>.*` Manual jika Domain Diatur di Coolify UI**:
   Ketika Anda mengisi kolom **Domains** pada service Docker Compose di Coolify UI (misal `https://api.laju.chat:3000`), Coolify secara otomatis menginjeksi label Traefik berikut ke kontainer:
   - `traefik.enable=true`
   - `traefik.http.routers.http-0-<uuid>-<service>...`
   - `traefik.http.services.http-0-<uuid>-<service>-<port>.loadbalancer.server.port=<port>`
   - `traefik.http.routers.https-0-<uuid>-<service>...`
   - `traefik.http.services.https-0-<uuid>-<service>-<port>.loadbalancer.server.port=<port>`

   > [!WARNING]
   > **Hindari Duplikasi Service Label Traefik!**
   > Jangan menambahkan label manual seperti `traefik.http.services.<service>.loadbalancer.server.port=...` atau `traefik.http.routers.<service>...` di `docker-compose.yml` jika domain sudah diatur melalui Coolify UI.
   > Menambahkan label service manual di atas label otomatis Coolify akan menyebabkan Traefik melihat banyak service sekaligus dalam satu kontainer dan memicu error berulang di `coolify-proxy`:
   > `ERR Router <service> cannot be linked automatically with multiple Services: ["http-0-<uuid>-<service>-<port>" ... "<service>"]`

---

## 2. Pengaturan di Coolify Dashboard UI

### A. Konfigurasi Domain Service pada Docker Compose Stack
Di Coolify > Project > **Docker Compose Resource**:
- **`api`**: Set domain dengan port internal `:3000` (contoh: `https://api.laju.chat:3000`)
- **`backoffice`**: Set domain dengan port internal `:3000` (contoh: `https://backoffice.laju.chat:3000`)
- **`portal`**: Set domain dengan port internal `:3002` (contoh: `https://laju.chat:3002`)

### B. Docker Network Traefik & Compose Network
Pada `docker-compose.yml`, service `api`, `portal`, dan `backoffice` terhubung ke dua network:
- `internal` (`internal: true`): Network terisolasi untuk akses database PostgreSQL, Redis, Gotify, dan SeaweedFS.
- `edge`: Network jembatan yang otomatis diintegrasikan oleh Coolify ke network `coolify` (`coolify-proxy`).

### C. Keamanan Data Produksi (Data Persistence Guarantee)
Konfigurasi Zero-Downtime ini murni mengatur alur *rolling update* dan perutean proxy Traefik:
- Volume penyimpanan database (`postgres_data`, `redis_data`, `gotify_data`, `seaweedfs_*`, `admin_media_data`) **100% aman dan tidak tersentuh**.
- Data produksi, riwayat chat, media, dan pengguna tetap tersimpan utuh di persistent storage host.

---

## 3. Cara Menjalankan True Rolling Update (`start-first`) dengan `docker-rollout`

Secara bawaan, perintah standar `docker compose up -d` (non-Swarm) mengabaikan properti `deploy.update_config.order: start-first` dan akan menghentikan kontainer lama terlebih dahulu sebelum menyalakan kontainer baru.

Untuk mencapai **100% Zero-Downtime Rolling Update** pada Docker Compose di VPS Coolify:

### Langkah 1: Install plugin `docker-rollout` di VPS (Cukup Sekali)
Jalankan perintah berikut di terminal root VPS (`vmi2685030`):
```bash
mkdir -p ~/.docker/cli-plugins
curl -sSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout -o ~/.docker/cli-plugins/docker-rollout
chmod +x ~/.docker/cli-plugins/docker-rollout
```

### Langkah 2: Cara Kerja `docker rollout`
Saat meng-update service aplikasi (`api`, `backoffice`, atau `portal`):
1. `docker rollout` menaikkan jumlah kontainer menjadi 2 (`--scale <service>=2`).
2. Menunggu hingga kontainer baru menyelesaikan migrasi dan berstatus **`healthy`** di Docker (selama fase ini Traefik tetap mengarahkan 100% trafik ke kontainer lama).
3. Begitu kontainer baru `healthy`, Traefik otomatis mendaftarkan kontainer baru ke load balancer.
4. `docker rollout` mengirimkan sinyal `SIGTERM` ke kontainer lama dan menunggu `stop_grace_period` hingga koneksi in-flight selesai, lalu menghapus kontainer lama.

Contoh penggunaan manual di direktori compose Coolify (`/data/coolify/applications/<uuid>` atau `/data/coolify/services/<uuid>`):
```bash
docker compose build api backoffice portal
docker rollout api
docker rollout backoffice
docker rollout portal
```

---

## 4. Graceful Shutdown & WebSocket Draining

Service NestJS (`api`) telah dilengkapi:
- `app.enableShutdownHooks();` di `src/main.ts`.
- `stop_grace_period: 25s` di `docker-compose.yml`.

Saat kontainer lama menerima sinyal `SIGTERM`:
1. Traefik langsung berhenti mengarahkan request HTTP baru ke kontainer lama.
2. Kontainer lama memiliki jendela waktu 25 detik untuk menyelesaikan request HTTP in-flight dan menutup koneksi WebSocket/SSE secara aman.
3. Aplikasi mobile/web otomatis melakukan reconnect instan ke kontainer baru yang sudah berstatus `healthy`.

---

## 5. Troubleshooting: Mengatasi Error `Router cannot be linked automatically with multiple Services`

Jika di `docker logs coolify-proxy` muncul pesan seperti:
```text
ERR Router web cannot be linked automatically with multiple Services: ["http-0-<uuid>-web-2567" "http-1-<uuid>-web-2567" "https-0-<uuid>-web-2567" "https-1-<uuid>-web-2567" "web"] providerName=docker routerName=web
```

### Penyebab:
Kontainer service tersebut (misalnya service `web` pada resource Coolify `<uuid>`) memiliki **label Traefik ganda**: label otomatis dari Coolify UI (`http-0-...`, `https-0-...`) ditambah label manual di `docker-compose.yml` (`traefik.http.services.web.*` dan/atau `traefik.http.routers.web.*` tanpa `.service=web`). Hal ini juga dapat menyebabkan kegagalan perpanjangan SSL Let's Encrypt (`Cannot retrieve the ACME challenge`).

### Cara Memperbaiki:
1. Cari kontainer yang bermasalah di VPS:
   ```bash
   docker ps --filter "name=ctlvlmmt1zqohpfjsaq8rnmy"
   ```
2. Buka konfigurasi `docker-compose.yml` dari aplikasi tersebut di Coolify UI (atau repo Git-nya).
3. Hapus seluruh label manual `traefik.http.services.web.*` dan `traefik.http.routers.web.*` dari bagian `labels:` pada service `web`.
4. Cukup sisakan blok `healthcheck:` bawaan Docker pada service `web`, dan biarkan pengaturan domain + port (`:2567`) dikelola sepenuhnya oleh kolom **Domains** di Coolify UI.
5. Klik **Deploy / Restart** pada aplikasi tersebut di Coolify UI, lalu pantau kembali:
   ```bash
   docker logs --since 1m -f coolify-proxy
   ```
