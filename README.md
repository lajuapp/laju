# LAJU Messenger

<p align="center">
  <br>
  <strong>Calm by Design • End-to-End Encrypted • Phoneless & Passwordless • Open Source</strong>
  <br>
  A modern, high-assurance secure messaging platform built on cryptographic sovereignty.
  <br><br>
</p>

<p align="center">
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-GNU%20AGPLv3-blue.svg?style=flat-square" alt="License: AGPLv3"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Platform-Android%20%7C%20Flutter-02569B.svg?style=flat-square&logo=flutter&logoColor=white" alt="Platform: Flutter"></a>
  <a href="https://nestjs.com"><img src="https://img.shields.io/badge/Backend-NestJS-E0234E.svg?style=flat-square&logo=nestjs&logoColor=white" alt="Backend: NestJS"></a>
  <a href="https://nextjs.org"><img src="https://img.shields.io/badge/Web-Next.js%2014-black.svg?style=flat-square&logo=next.js&logoColor=white" alt="Web: Next.js"></a>
  <a href="https://www.postgresql.org"><img src="https://img.shields.io/badge/Database-PostgreSQL%2016-336791.svg?style=flat-square&logo=postgresql&logoColor=white" alt="Database: PostgreSQL"></a>
  <a href="https://webrtc.org"><img src="https://img.shields.io/badge/Calls-WebRTC%20P2P-333333.svg?style=flat-square&logo=webrtc&logoColor=white" alt="Calls: WebRTC"></a>
</p>

---

## Overview

**LAJU** was born from a simple longing: an instant messaging platform that is quiet, lightweight, and genuinely respectful of personal boundaries. In a world saturated with digital noise, notification anxiety, and surveillance capitalism, conversations with your closest family and friends should be a sanctuary—not an arena for attention extraction.

- **Zero PII (No Personal Identifiable Information)**: No phone number, no cellular SMS verification, and no email required. Your identity is rooted entirely in device-generated asymmetric cryptographic keypairs (Ed25519 & X25519).
- **Calm by Design**: No algorithmic recommendation feeds, no unread badge anxiety, no third-party advertising SDKs, and no tracking cookies.
- **Pure Cryptographic Sovereignty**: Message plaintext never exists on server infrastructure. The server only routes end-to-end encrypted ciphertext envelopes.
- **Autonomous Distribution**: Independent of proprietary app stores, featuring a native One-Click In-App OTA APK Installer.

---

## Key Features

### 🔒 Privacy & Cryptography
- **Double Ratchet E2EE**: Forward secrecy and break-in recovery for personal (1:1) and group conversations.
- **Phoneless Registration**: Cryptographic nonce challenge verification during device registration; no contact books uploaded to servers.
- **Disappearing Messages**: Configurable ephemeral timers that automatically purge message payloads across all devices and servers.
- **App Lock & Biometrics**: Local application protection via Master PIN and hardware biometrics (Fingerprint / Face Unlock), protected by Android `FLAG_SECURE`.
- **Data Sovereignty & Account Obliteration**: One-tap instant account deletion (`DELETE /users/me`) with structured feedback, permanent cryptographic key destruction, and group deletion requiring Master PIN confirmation.

### 💬 Messaging & Rich Interactions
- **Low-Latency Messaging**: Sub-50ms message relay via persistent Server-Sent Events (SSE) and Redis Pub/Sub.
- **Message Reactions**: Expressive emoji reactions synchronized across conversation members.
- **Custom Sticker Packs**: Server-curated high-resolution sticker library with local disk caching.
- **Chat Wallpapers**: Customizable backgrounds per chat or globally, with adaptive brightness reduction.
- **Voice Notes**: Inline waveform visualization with audio scrubbing and variable playback speeds (1.0x, 1.5x, 2.0x).
- **Live Location Sharing**: Ephemeral coordinate sharing with strict real-time expiration.

### 🎥 WebRTC Audio & Video Calling
- **Peer-to-Peer Encrypted Calls**: Direct DTLS-SRTP media streaming with STUN/TURN fallback.
- **Group Calls**: Multi-party audio/video conferencing with dynamic mesh peer negotiation.
- **Background PIP Overlay**: Non-blocking in-app floating overlay to continue texting while in a call.
- **Intelligent Call Notifications**: Full-Screen Intent incoming call display when locked, and non-blocking in-app banners when open (zero duplicate notifications).

### 📖 Ephemeral Status & Stories (24h)
- **24-Hour Self-Destructing Updates**: Share text, photo, and video status stories with mutual contacts.
- **Video Range Streaming**: High-performance HTTP 206 Partial Content byte-range video streaming for buffer-free playback on constrained networks.
- **Granular Privacy Whitelist/Blacklist**: Share with *All Contacts*, *My Contacts Except...*, or *Only Share With...*.
- **Official System Announcements**: Operator broadcast stories pinned to the Status feed.

---

## Monorepo Architecture

LAJU is organized as a unified monorepo managed with `pnpm` workspaces:

```text
laju/
├── apps/
│   ├── mobile/         # Android application built with Flutter
│   ├── api/            # Backend Modular Monolith built with NestJS & Prisma
│   ├── worker/         # Asynchronous worker for outbox events & retention cleanup
│   ├── backoffice/     # Administrative governance & compliance console (Next.js)
│   └── portal/         # Public landing page, manifesto & APK gateway (Next.js)
├── packages/
│   ├── contracts/      # Shared protocol contracts and DTO schemas
│   ├── shared-types/   # Cross-platform TypeScript type definitions
│   └── ui/             # Reusable UI component library
├── infrastructure/     # Dockerfiles, Traefik proxy configurations & scripts
├── docs/               # Full technical, protocol, and architecture documentation
├── docker-compose.yml  # Production & local development orchestrator
├── LICENSE.md          # GNU Affero General Public License v3.0
├── TRADEMARK.md        # Trademark, brand assets, and infrastructure policy
└── README.md
```

### System Topology

```text
                         ┌──────────────────────┐
                         │ Reverse Proxy / WAF  │
                         └──────────┬───────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
  ┌──────▼──────┐            ┌──────▼──────┐            ┌──────▼──────┐
  │ Next.js     │            │ Next.js     │            │ NestJS API  │
  │ Portal      │            │ Backoffice  │            │ Modular     │
  │ (:3002)     │            │ (:3000)     │            │ (:3000)     │
  └─────────────┘            └──────┬──────┘            └──────┬──────┘
                                    │                          │
                               Admin API            ┌──────────┴──────────┐
                                                    │                     │
                                              ┌─────▼────┐          ┌─────▼────┐
                                              │PostgreSQL│          │  Redis   │
                                              │  (:5432) │          │  (:6379) │
                                              └──────────┘          └─────┬────┘
                                                                          │
                                                                    ┌─────▼────┐
                                                                    │SeaweedFS │
                                                                    │  (:8888) │
                                                                    └──────────┘
```

---

## Quick Start (Self-Hosting)

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/) v2+
- [Node.js](https://nodejs.org/) v20+ and [pnpm](https://pnpm.io/) v9+ (for local development)
- [Flutter SDK](https://flutter.dev/) v3.19+ (for mobile development)

### 1. Clone the Repository
```bash
git clone https://github.com/lajuapp/laju.git
cd laju
```

### 2. Configure Environment Variables
```bash
cp .env.example .env
```
Adjust `.env` variables (database passwords, JWT secret, and domain names) as needed.

### 3. Launch Services with Docker Compose
```bash
docker compose up -d
```

Verify service health:
```bash
docker compose ps
```

| Service | Port | Description |
| :--- | :--- | :--- |
| **Portal** | `http://localhost:3002` | Public landing page and APK download portal |
| **Backoffice** | `http://localhost:3000` | Administrative control panel |
| **API** | `http://localhost:3000` | NestJS backend service & WebSocket/SSE gateway |
| **PostgreSQL** | `5432` | Relational database |
| **Redis** | `6379` | Real-time PubSub & session cache |
| **SeaweedFS** | `8888` | Distributed blob storage for encrypted attachments |

---

## Licensing & Dual-Licensing Model

LAJU is committed to open source, transparency, and digital freedom while safeguarding its community and infrastructure. The codebase is governed under a **dual-licensing and trademark model**:

### 1. Free Software under GNU AGPLv3
Except where otherwise noted, the entire LAJU codebase is free software licensed under the **[GNU Affero General Public License v3.0 (GNU AGPLv3)](LICENSE.md)**.

- **You are free to**: Inspect, audit, study, run, modify, and self-host the software for personal, academic, community, or internal organizational purposes.
- **Copyleft Reciprocity (Section 13)**: If you modify this program and run it as a network service accessible to users, **you are legally obligated to make the complete corresponding source code available to all network users under the same GNU AGPLv3 license**.

### 2. Commercial Dual-Licensing Exemption
For enterprises, commercial entities, or partners that require:
- Proprietary closed-source embedding or application distribution,
- White-label commercial products based on LAJU,
- Exemption from the AGPLv3 network copyleft obligations,

an official **Commercial Enterprise License** is available.

📧 **Commercial Licensing Inquiries**: [licensing@laju.chat](mailto:licensing@laju.chat)

### 3. Trademark and Infrastructure Policy
The open availability of source code under GNU AGPLv3 does **not** grant rights to the LAJU trademark or access to official hosted services:

- **Branding**: The name **"LAJU"**, logos, emblem, visual identity, and brand assets are protected trademarks. Any public fork or derivative distribution **must be rebranded** with all LAJU marks removed.
- **Infrastructure Protection**: Forks and third-party builds are **strictly prohibited** from connecting to official LAJU production infrastructure (including official push notification relays, production TURN servers, and user registries). Forks must operate independent server infrastructure.

For detailed guidelines, see **[TRADEMARK.md](TRADEMARK.md)**.

---

## Documentation

Comprehensive engineering documentation is maintained in the [`docs/`](docs/) directory:

- 🏛️ **[Architecture Overview](docs/architecture/overview.md)** — Modular monolith, clean architecture, trust boundaries.
- 📡 **[API Specification](docs/api/api.md)** — Complete HTTP routes, SSE push streams, and payload schemas.
- 🛡️ **[Admin & Backoffice API](docs/api/admin-api.md)** — Operator endpoints, telemetry, and moderation tools.
- 🗄️ **[Database Schema](docs/database/schema.md)** — Relational tables, indexing strategies, and data classifications.
- 🔔 **[Mobile Notifications](docs/mobile/notifications.md)** — Android native push service, SSE streaming, and Doze management.
- 🎨 **[Portal Design System](docs/portal/design-system.md)** — Calm by Design standards and Architectural Pillars pattern.
- 📱 **[Feature Guides](docs/features/)** — In-depth specifications for Status, App Lock, Rich Messaging, and OTA Updates.

---

## Security Vulnerability Reporting

Security and user privacy are the highest priorities of the LAJU project. If you discover a potential security flaw or cryptographic vulnerability, please **do not open a public GitHub issue**.

Please disclose vulnerabilities responsibly by contacting:

🔐 **Security Team**: [security@laju.chat](mailto:security@laju.chat)  
🛡️ **Privacy Compliance**: [privacy@laju.chat](mailto:privacy@laju.chat)

We appreciate your cooperation in coordinated responsible disclosure.

---

<p align="center">
  <sub>Built with care by the LAJU Community. Free and open communications for all.</sub>
</p>
