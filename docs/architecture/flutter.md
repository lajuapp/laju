# Flutter Android Architecture

## Project

```text
apps/mobile/
└── lib/
    ├── app/
    ├── core/
    │   ├── crypto/
    │   ├── security/
    │   ├── network/
    │   ├── storage/
    │   └── platform/
    ├── database/
    └── features/
        ├── authentication/
        ├── devices/
        ├── conversations/
        ├── messaging/
        ├── attachments/
        ├── calls/
        └── settings/
```

## Layers

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Infrastructure
```

The UI must not directly access:

- cryptographic keys
- SQLite
- HTTP clients
- Android Keystore
- WebRTC internals

Use repositories/use cases.

## Mobile responsibilities

- identity key generation
- E2EE session establishment
- message encryption/decryption
- group crypto state
- encrypted local database
- attachment encryption/decryption
- offline queue
- event cursor
- key verification
- device registration
- call UI and WebRTC lifecycle
- local app lock
- incident containment handling
