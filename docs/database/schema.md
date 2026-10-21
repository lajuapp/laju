# Database Schema

The database is PostgreSQL 16 managed via Prisma ORM (`apps/api/prisma/schema.prisma`). It enforces strict relational integrity, foreign key cascading, and zero plaintext exposure for end-to-end encrypted message payloads.

---

## 1. Complete Entity Registry

### Identity, Devices & Cryptography
| Table / Model | Description |
| :--- | :--- |
| `User` | Core user identity (public master Ed25519 identity key, display name, avatar, bio, active state) |
| `OtpCode` | Ephemeral verification codes for emergency recovery or specific identity binding |
| `Device` | Physical device keypair (Ed25519 identity key, X25519 prekey, push token, platform, last seen) |
| `DeviceKey` | Device cryptographic key metadata and verification status |
| `PreKey` | Signed and one-time ephemeral X25519 prekeys for asynchronous double-ratchet session establishment |
| `Session` | Active authenticated client sessions with refresh tokens and expiration |
| `DeviceMigration` | Ephemeral 2PC state for cross-device QR code account migration |
| `DeviceTransferRequest` | Out-of-band device session transfer negotiation |
| `PushDevice` | Push relay routing mapping device push tokens to notification channels |

### Communication & Messaging
| Table / Model | Description |
| :--- | :--- |
| `Conversation` | Direct (1:1) and Group conversation containers with title, avatar, and disappearing timer |
| `ConversationMember` | Participant mapping with roles (`OWNER`, `ADMIN`, `MEMBER`), joined timestamps, and muted state |
| `Message` | Ciphertext envelope (nonce, encrypted payload, sequence number, expiration timestamp) |
| `MessageDelivery` | Per-recipient delivery receipts (`SENT`, `DELIVERED`, `READ`) with cryptographic timestamps |
| `ConversationEvent` | System events within conversations (member joined, left, renamed, timer changed) |
| `Attachment` | Encrypted media blob metadata (SeaweedFS storage path, MIME type, ciphertext size) |
| `MessageReaction` | Emoji reactions on messages (`messageId`, `userId`, `emoji`, `createdAt`) |

### Status & Ephemeral Stories
| Table / Model | Description |
| :--- | :--- |
| `UserStatusStory` | 24-hour self-expiring text and media status stories with custom audience privacy rules |
| `StatusStoryView` | Read receipts tracking viewers of a user's story (`storyId`, `viewerUserId`, `viewedAt`) |

### Media Customization & Rich Interactions
| Table / Model | Description |
| :--- | :--- |
| `ChatWallpaper` | Curated and custom background themes for chats (`imageUrl`, `category`, `isDefault`) |
| `StickerPack` | Collection of stickers curated for the messenger (`name`, `coverUrl`, `author`) |
| `StickerItem` | Individual sticker assets (`packId`, `name`, `imageUrl`, `emoji`) |

### Real-Time Calls (WebRTC)
| Table / Model | Description |
| :--- | :--- |
| `Call` | Audio/video call session container (`type`, `status`: `RINGING`, `CONNECTED`, `ENDED`, `MISSED`) |
| `CallParticipant` | Participant state, joined/left timestamps, SDP signaling records, and network stats |

### Governance, Compliance & Backoffice
| Table / Model | Description |
| :--- | :--- |
| `AdminUser` | Operator credentials, email, password hash, role assignment, and active status |
| `AdminRole` | Role definitions (`SUPER_ADMIN`, `SUPPORT_AGENT`, `COMPLIANCE_OFFICER`, etc.) |
| `AdminPermission` | Granular permission constants |
| `AdminRolePermission` | Mapping between roles and allowed permissions |
| `AdminSession` | Operator session tokens with IP binding and last active timestamp |
| `AdminAuditEvent` | Tamper-evident immutable audit log of operator actions |
| `ConversationAccessGrant` | Dual-control compliance authorization record for metadata inspection |
| `ConversationAccessApproval` | Multi-signature approvals validating compliance grants |
| `RetentionPolicy` | Automated server-side ciphertext purging schedules per conversation type |
| `UserReport` | Abuse, spam, and harassment reports submitted by users |
| `SupportTicket` | User support inquiries and administrative resolution threads |
| `Location` | Ephemeral and live location sharing coordinates with strict TTL expiration |
| `Incident` | Active security anomalies, breach containment, and lockdown states |
| `IncidentTarget` | Targeted identities or devices affected by active incident containment |
| `SystemAnnouncement` | Official announcements broadcasted to all active clients |
| `AppSystemConfig` | Global client application versioning policies, minimum build requirements, and APK downloads |
| `DownloadAnalyticsEvent` | Metrics tracking APK download sources, referrals, and geographical conversions |
| `SecurityEvent` | Security telemetry logging cryptographic failures, revoked tokens, and MITM flags |
| `OutboxEvent` | Transactional outbox event records guaranteed for reliable asynchronous worker processing |

---

## 2. Core Relational Invariants

### A. Message Invariant
```text
Message Table:
- (sender_device_id, client_message_id) is UNIQUE.
- (conversation_id, sequence) is INDEXED for strict monotonic ordering.
- Ciphertext is NEVER stored in plaintext. Server holds zero decryption keys.
- Expired messages are pruned automatically when now() > expires_at.
```

### B. Status Story Invariant
```text
UserStatusStory Table:
- expires_at is automatically indexed and defaulted to createdAt + 24 hours.
- StatusStoryView records (story_id, viewer_user_id) uniquely to ensure single-view counting.
```

### C. WebRTC Call Invariant
```text
Call & CallParticipant:
- Calls ringing longer than 60 seconds without acceptance automatically transition to MISSED.
- Audio and video media are transmitted peer-to-peer or via TURN; media plaintext is NEVER stored on the database.
```
