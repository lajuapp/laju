<p align="center">
  <img src="apps/portal/public/images/logo_no_bg.png" alt="LAJU Logo" width="120" />
</p>

<h1 align="center">LAJU Messenger</h1>

<p align="center">
  <strong>End-to-End Encrypted • Device-Key Identity • Open Source</strong>
  <br>
  A modern, high-assurance secure messaging platform engineered for privacy, reliability, and cryptographic sovereignty.
</p>

<p align="center">
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-GNU%20AGPLv3-00C896.svg?style=flat-square" alt="License: AGPLv3"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Client-Android%20%7C%20Flutter-02569B.svg?style=flat-square&logo=flutter&logoColor=white" alt="Platform: Flutter"></a>
  <a href="https://nestjs.com"><img src="https://img.shields.io/badge/Backend-NestJS-E0234E.svg?style=flat-square&logo=nestjs&logoColor=white" alt="Backend: NestJS"></a>
  <a href="https://nextjs.org"><img src="https://img.shields.io/badge/Web-Next.js%2014-000000.svg?style=flat-square&logo=next.js&logoColor=white" alt="Web: Next.js"></a>
  <a href="https://www.postgresql.org"><img src="https://img.shields.io/badge/Database-PostgreSQL%2016-336791.svg?style=flat-square&logo=postgresql&logoColor=white" alt="Database: PostgreSQL"></a>
  <a href="https://webrtc.org"><img src="https://img.shields.io/badge/Calls-WebRTC%20P2P-333333.svg?style=flat-square&logo=webrtc&logoColor=white" alt="Calls: WebRTC"></a>
</p>

---

## Overview

**LAJU** is an instant messaging and peer-to-peer communication platform designed with a primary focus on user privacy, lightweight operation, and calm digital communication. Built without dependency on phone numbers, cellular SMS verification, or centralized advertising trackers, LAJU ensures that conversations remain private between participating parties.

- **Cryptographic Identity**: Identity is established on-device via asymmetric cryptographic keypairs (Ed25519 & X25519). No phone numbers, SMS verification codes, or personal contact books are required or harvested.
- **End-to-End Encryption**: Direct and group conversations are protected by the Double Ratchet protocol with forward secrecy and break-in recovery.
- **Zero Plaintext on Relay**: Message contents are encrypted on the sender's device before transit. Servers act strictly as ciphertext relays and temporary offline queues.
- **Direct WebRTC Calling**: Audio and video calls connect peer-to-peer using DTLS-SRTP encryption, minimizing latency and bandwidth consumption.
- **Clean and Respectful Architecture**: No surveillance SDKs, no tracking pixels, no algorithmic recommendation feeds, and transparent permanent account deletion.

---

## Key Features

### Privacy and Cryptography
- **Double Ratchet Protocol**: Cryptographic forward secrecy and post-compromise security for 1-on-1 and group messaging sessions.
- **Phoneless Registration**: Cryptographic nonce challenge verification during device setup; no personal contact numbers are exposed or logged.
- **Disappearing Messages**: Configurable ephemeral timers (from 1 hour to 90 days) that automatically purge message payloads across all devices and server queues.
- **Biometric App Lock**: Application security backed by Android Keystore, Master PIN, and biometric authentication (Fingerprint / Face Unlock), enforced with `FLAG_SECURE` screen protection.
- **Permanent Account Obliteration**: One-step account deletion (`DELETE /users/me`) that purges user sessions, cryptographic keys, and profile records from database servers.

### Messaging and Rich Interactions
- **Low-Latency Message Delivery**: Sub-50ms delivery times via persistent Server-Sent Events (SSE) and Redis Pub/Sub channels.
- **Message Reactions**: Synchronized emoji reactions across 1-on-1 and group chats.
- **Custom Sticker Engine**: Curated sticker collection support with localized caching on device storage.
- **Chat Personalization**: Custom wallpapers per conversation with automated dark mode dimming.
- **Voice Notes**: Inline waveform rendering, audio seeking, and variable playback speeds (1.0x, 1.5x, 2.0x).
- **Live Location Sharing**: Real-time ephemeral coordinate sharing protected by countdown timers.

### Audio and Video Calling (WebRTC)
- **Peer-to-Peer Encryption**: Direct audio/video transmission using DTLS-SRTP with automated STUN/TURN traversal fallback.
- **Group Mesh Calls**: Multi-party conferencing with dynamic peer mesh renegotiation.
- **In-App Picture-in-Picture (PiP)**: Floating call overlay allowing continued text communication while on an active call.
- **Foreground Call Handling**: Full-Screen Intent incoming call interface when the device is locked, transitioning to non-intrusive banners when unlocked.

### Ephemeral Status and Stories
- **24-Hour Ephemeral Updates**: Text, photo, and video status stories shared with mutual contacts.
- **HTTP 206 Partial Content Streaming**: Byte-range video streaming for smooth playback under low-bandwidth network conditions.
- **Selective Audience Controls**: Granular privacy settings (*All Contacts*, *My Contacts Except...*, or *Only Share With...*).
- **System Broadcasts**: Pinned official announcements from operators without algorithmic feed injection.

---

## Architecture and Monorepo Structure

LAJU is structured as a unified monorepo powered by `pnpm` workspaces:

```text
laju/
├── apps/
│   ├── mobile/         # Android application built with Flutter & Dart
│   ├── api/            # Modular backend monolith built with NestJS & Prisma ORM
│   ├── worker/         # Asynchronous worker for retention cleanup and task queues
│   ├── backoffice/     # Operational governance & admin console (Next.js)
│   └── portal/         # Public landing page, release portal & APK distribution (Next.js)
├── packages/
│   ├── contracts/      # Shared API contracts and DTO schemas
│   ├── shared-types/   # Cross-platform TypeScript type definitions
│   └── ui/             # Shared web UI component library
├── infrastructure/     # Dockerfiles, reverse proxy configurations, and deployment scripts
├── docs/               # System documentation, API references, and architecture guides
├── docker-compose.yml  # Local development and container orchestration
├── LICENSE.md          # GNU Affero General Public License v3.0
└── TRADEMARK.md        # Trademark and infrastructure usage policy
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

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/) v2+
- [Node.js](https://nodejs.org/) v20+ and [pnpm](https://pnpm.io/) v9+ (for local monorepo development)
- [Flutter SDK](https://flutter.dev/) v3.19+ (for mobile client compilation)

### 1. Clone the Repository

```bash
git clone https://github.com/lajuapp/laju.git
cd laju
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Review and adjust variables in `.env` (database credentials, JWT signing secrets, and network hostnames).

### 3. Start Containerized Services

```bash
docker compose up -d
```

Verify service status:

```bash
docker compose ps
```

### Service Map

| Service | Port | Description |
| :--- | :--- | :--- |
| **Portal** | `http://localhost:3002` | Public web portal and APK download gateway |
| **Backoffice** | `http://localhost:3000` | Administrative control panel |
| **API Gateway** | `http://localhost:3000` | NestJS REST API, SSE streaming, and WebSocket endpoints |
| **PostgreSQL** | `5432` | Relational database (v16) |
| **Redis** | `6379` | Message broker, Pub/Sub, and cache layer |
| **SeaweedFS** | `8888` | Distributed blob storage for encrypted attachments |

---

## Licensing and Governance

LAJU is committed to transparency and open-source collaboration while maintaining project sustainability and network security.

### 1. Free Software under GNU AGPLv3
Except where explicitly stated otherwise, the LAJU codebase is licensed under the **[GNU Affero General Public License v3.0 (GNU AGPLv3)](LICENSE.md)**.

- **Open Usage**: You are free to inspect, study, run, modify, and host the software for personal, non-commercial, community, or internal organizational purposes.
- **Copyleft Reciprocity (Section 13)**: If you modify this program and offer it as a service over a network, you must make the corresponding source code publicly available under the same GNU AGPLv3 license terms.

### 2. Commercial Dual-Licensing Exemption
For enterprises and commercial entities that require:
- Proprietary closed-source embedding or application distribution,
- White-label commercial products based on LAJU,
- Exemption from the AGPLv3 network copyleft obligations,

an official **Commercial Enterprise License** is available.

**Commercial Licensing and Inquiries**: [hallo@laju.chat](mailto:hallo@laju.chat)

### 3. Trademark and Infrastructure Policy
The open availability of source code under GNU AGPLv3 does not grant rights to LAJU trademarks or access to official hosted services:

- **Branding**: The name **"LAJU"**, logos, emblem, visual identity, and brand assets are protected trademarks. Any public fork or derivative distribution must be rebranded with all LAJU marks removed.
- **Infrastructure Protection**: Third-party builds and forks must operate their own server infrastructure. Connecting external builds to official LAJU production relays, TURN servers, or user registries without authorization is strictly prohibited.

For complete guidelines, refer to **[TRADEMARK.md](TRADEMARK.md)**.

---

## Engineering Documentation

Detailed specifications and architectural guides are maintained in the [`docs/`](docs/) directory:

- **[Architecture Overview](docs/architecture/overview.md)**: Modular monolith structure, domain boundaries, and cryptographic flows.
- **[API Specification](docs/api/api.md)**: HTTP route catalog, SSE push streams, and payload validation schemas.
- **[Admin & Backoffice API](docs/api/admin-api.md)**: Administrative governance, telemetry, and moderation tools.
- **[Database Schema](docs/database/schema.md)**: Entity models, indexing strategies, and data lifecycle management.
- **[Mobile Notifications](docs/mobile/notifications.md)**: Android foreground service, SSE streaming, and battery optimization.
- **[Portal Design System](docs/portal/design-system.md)**: Design principles, typography, and component styling.
- **[Feature Guides](docs/features/)**: Specifications for Status, App Lock, Rich Messaging, and OTA Updates.

---

## Responsible Security Disclosure

Security and user privacy are foundational to LAJU. If you identify a potential security vulnerability or cryptographic flaw, please disclose it responsibly. Do not open public GitHub issues for security matters.

Please report vulnerabilities to:

- **Security Advisories**: [security@laju.chat](mailto:security@laju.chat)
- **General Inquiries & Community**: [hallo@laju.chat](mailto:hallo@laju.chat)

We appreciate your collaboration in coordinated, responsible vulnerability disclosure.

---

<p align="center">
  <sub>Built with care by the LAJU Community. Free and open communication for all.</sub>
</p>
