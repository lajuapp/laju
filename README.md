# Secure Messenger — Full System Documentation

## 1. Product

High-assurance secure communications platform consisting of:

- Android mobile application — Flutter
- Backend — NestJS Modular Monolith
- Backoffice — Next.js
- PostgreSQL
- Redis
- Gotify
- SeaweedFS
- WebRTC voice/video calling
- Docker Compose
- Single Git monorepo
- Clean Architecture + Use Case Pattern
- E2EE personal and group messaging
- Multi-device
- Offline synchronization
- Controlled administrative access
- Security incident containment

## 2. Security position

The system uses established, audited cryptographic protocols/libraries. It does not implement custom cryptography.

Normal server operation does not require message plaintext.

The Backoffice is a separate administrative security boundary. If an authorized administrative conversation-access feature can reveal plaintext, that feature is explicitly treated as an exceptional access path and is not described as pure zero-knowledge E2EE.

## 3. Repository

```text
secure-messenger/
├── apps/
│   ├── api/
│   ├── worker/
│   ├── mobile/
│   └── backoffice/
├── packages/
│   ├── contracts/
│   ├── shared-types/
│   └── ui/
├── infrastructure/
│   └── docker/
├── docs/
├── docker-compose.yml
├── .env.example
└── README.md
```

## 4. System topology

```text
                         ┌──────────────────────┐
                         │ Reverse Proxy / WAF  │
                         └──────────┬───────────┘
                                    │
                  ┌─────────────────┴────────────────┐
                  │                                  │
           ┌──────▼──────┐                    ┌──────▼──────┐
           │ Next.js     │                    │ NestJS API  │
           │ Backoffice  │                    │ Modular     │
           └──────┬──────┘                    │ Monolith    │
                  │                           └──────┬──────┘
                  │                                  │
                  │             ┌────────────────────┼──────────────┐
                  │             │                    │              │
             Admin API       ┌──▼───┐             ┌──▼───┐      ┌──▼─────┐
                             │ PG   │             │Redis  │      │Seaweed │
                             └──────┘             └──┬────┘      │FS      │
                                                     │           └────────┘
                                                  ┌──▼───┐
                                                  │Gotify │
                                                  └───────┘

Flutter Android
 ├── E2EE
 ├── encrypted SQLite
 ├── Android Keystore
 ├── offline sync
 └── WebRTC
        │
        └────────────── NestJS signaling/API
```

## 5. Core rule

```text
Client
  → encryption/decryption

NestJS
  → authentication
  → authorization
  → lifecycle
  → synchronization
  → metadata
  → signaling

PostgreSQL
  → authoritative state

Redis
  → transient realtime/outbox delivery

Gotify
  → generic wakeup

SeaweedFS
  → encrypted blobs

Backoffice
  → controlled administration
```
