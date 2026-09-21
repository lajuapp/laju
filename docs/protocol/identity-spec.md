# LAJU Device-Centric Cryptographic Identity & Migration Specification

## 1. Target Architecture & Philosophy

LAJU operates on a **Device-Centric, Passwordless & Phone-less Cryptographic Identity** model. 
There is **no SMS verification**, **no email authentication**, **no passwords**, and **username is not a credential**.

```text
                    LAJU IDENTITY
                         │
              Portable Identity Secret (I)
                         │
              ┌──────────┴──────────┐
              │                     │
         DEVICE A                DEVICE B
              │                     │
       Device Key A           Device Key B
       Android Keystore       Android Keystore
              │                     │
              └────── Migration ────┘
```

### Core Concept: Identity vs. Device

| Domain | Identity (`Identity`) | Device (`Device`) |
| :--- | :--- | :--- |
| **Definition** | Who the user is across the LAJU network. | Which physical device currently holds the identity. |
| **Attributes** | `identity_id`, `identity_public_key`, `username` | `device_id`, `device_public_key`, `attestation_data`, `device_session` |
| **Persistence** | **PERMANENT** across device replacements. | **EPHEMERAL** (Created per physical device, revoked on migration). |
| **Key Material** | Derived from CSPRNG 32-byte portable identity secret ($). | Hardware-backed keypair in Android Keystore / Secure Enclave ({\text{device}}$). |

> **Key Rule**: When switching phones:
> - **Identity = TETAP (STAYS THE SAME)**
> - **Device Key = BERGANTI (REPLACED / NEW)**
> No new identity is created upon phone replacement; ownership is migrated cryptographically.

---

## 2. Hardware Keystore & Key Hierarchy

### Anti-Pattern: Exporting/Cloning Hardware Keys
Hardware-backed Keystore (TEE/StrongBox) is explicitly engineered to prevent private key extraction. It is **cryptographically unsound and physically impossible** to extract or export hardware private keys from Device A to Device B.

### Correct Design: Layered Envelope Cryptography

```text
                LAJU Identity
                     │
          Portable Identity Secret
                     │
          ┌──────────┴──────────┐
          │                     │
    Wrapped by Device A   Wrapped by Device B
          │                     │
    Keystore A              Keystore B
```

1. **Identity Secret ($)**: A 32-byte high-entropy seed generated via CSPRNG on initial setup.
2. **Device Hardware Key ({\text{device}}$)**: Generated inside Android Keystore (`KeyGenParameterSpec` with `PURPOSE_ENCRYPT | PURPOSE_DECRYPT | PURPOSE_SIGN`, hardware-backed with Attestation when available).
3. **Local Protection**: $ is encrypted (wrapped) by {\text{device}}$ before being persisted into SQLCipher. Plaintext $ only exists in volatile memory during active app usage.

---

## 3. Core Identity & Migration Entities

### Backend Data Models

#### `Identity`
```text
Identity
├── identity_id (UUID / Unique string identifier)
├── identity_public_key (Base64 / Hex Ed25519 or Curve25519)
├── username (Display alias, unique, NOT a credential)
├── status (REGISTERING | ACTIVE | SUSPENDED | CONTAINED)
├── created_at (Timestamp)
└── updated_at (Timestamp)
```

#### `Device`
```text
Device
├── device_id (UUID generated on initial device registration)
├── identity_id (Foreign Key -> Identity)
├── device_public_key (Base64 / Hex - Hardware Keystore Public Key)
├── attestation_data (Hardware Attestation certificate chain / payload)
├── platform (android | ios)
├── status (PENDING | ACTIVE | MIGRATING | REVOKED | DECOMMISSIONED)
├── registered_at (Timestamp)
├── last_seen_at (Timestamp)
└── revoked_at (Nullable Timestamp)
```

#### `DeviceMigration`
```text
DeviceMigration
├── migration_id (UUID)
├── identity_id (Foreign Key -> Identity)
├── source_device_id (Foreign Key -> Device)
├── target_device_id (Foreign Key -> Device)
├── status (PREPARED | TRANSFERRING | VERIFYING | COMMITTING | COMMITTED | FAILED | EXPIRED | CANCELLED)
├── challenge (One-time cryptographic nonce)
├── expires_at (Short TTL, e.g. 3-5 minutes)
├── created_at (Timestamp)
├── committed_at (Nullable Timestamp)
└── failure_reason (Nullable string)
```

---

## 4. First Installation Lifecycle

```text
Install LAJU
     ↓
Generate Identity (I = CSPRNG 32 bytes)
     ↓
Generate Device Key (Android Keystore / TEE)
     ↓
Wrap Identity Secret with Device Key
     ↓
Initialize Encrypted Local SQLite (SQLCipher)
     ↓
Register Device & Public Keys with Server
     ↓
Choose Username
     ↓
ACTIVE
```

### Local Storage Security (SQLCipher & Android Auto Backup Policy)
- **Local SQLite Database**: Encrypted using a key derived via HKDF from device hardware keystore.
- **Allowed Local Data**: `identity_id`, `identity_public_key`, `wrapped_identity_secret`, conversations, encrypted messages, group state, attachment references, sync state.
- **Strictly Prohibited**: `private_key_plaintext`, `identity_secret_plaintext`, passwords, migration session keys.
- **Android Auto Backup Exclusion**:
  `backup_rules.xml` must explicitly **EXCLUDE** all database files, keystore-related shared preferences, and credential caches to prevent unencrypted cloud extraction.

---

## 5. Device Authentication (Challenge-Response)

LAJU replaces conventional password/OTP login with **Hardware Cryptographic Attestation & Challenge-Response**:

```text
Open LAJU App
     ↓
Unlock App (Biometric / System Device PIN)
     ↓
Request Challenge from Server (POST /devices/challenge)
     ↓
Server Returns Nonce (challenge)
     ↓
Device Signs Challenge using Keystore Private Key
     signature = Sign(device_private_key, challenge)
     ↓
Server Verifies: Verify(device_public_key, challenge, signature)
     ↓
Cryptographic Session Established (JWT/Session Token bound to device_id)
```

---

## 6. QR Migration Protocol (Device A -> Device B)

Transferring an identity to a new phone without passwords or central servers holding private keys:

```text
                 ┌─────────────────────┐
                 │    LAJU IDENTITY    │
                 │  Identity Key/State │
                 └──────────┬──────────┘
                            │
                   ┌────────┴────────┐
                   │                 │
              DEVICE A           DEVICE B
                   │                 │
          Device Key A       Device Key B
          Keystore A         Keystore B
                   │                 │
                   └───────┬─────────┘
                           │
                    QR Migration
                           │
                Authenticated Channel
                           │
               Encrypted State Transfer
                           │
                     Verification
                           │
                         Commit
                      ┌────┴────┐
                      │         │
                 New ACTIVE   Old REVOKED
```

### Step-by-Step Flow:

1. **Source Device Initiation**:
   - User goes to `Settings -> Security -> Move to New Device`.
   - Source generates ephemeral keypair ({\text{source}}$) and requests `migration_id` from server.
   - Display dynamic QR code containing:
     ```json
     {
       "protocol": "LAJU-MIGRATION",
       "version": 1,
       "migrationId": "mig_uuid_xxx",
       "sourceDeviceId": "dev_source_xxx",
       "ephemeralPublicKey": "pub_ephemeral_source",
       "challenge": "random_nonce",
       "expiresAt": 1742468000
     }
     ```
   - **QR NEVER CONTAINS**: Private keys, identity secrets, message history, or recovery passwords.

2. **Target Device Scan**:
   - New phone installs LAJU, selects *"Restore Existing Identity"*, and scans the QR code.
   - Target generates its own hardware device key in Keystore ({\text{device\_B}}$) and ephemeral keypair ({\text{target}}$).
   - Target sends public material and challenge response to Source (via local WiFi Direct, WebRTC peer channel, or TLS relay).

3. **Authenticated Key Agreement & Mutual Out-of-Band Confirmation (SAS)**:
   - Both devices execute ECDH between {\text{source}}$ and {\text{target}}$ to compute `migration_session_key`.
   - Both devices derive a **Short Authentication String (SAS)** (e.g. 6 digits: `482 731`).
   - User visually confirms that the numbers match on both screens before proceeding.

4. **Encrypted Identity & State Transfer**:
   - Source unlocks $ from Keystore A.
   - Source encrypts $, conversation metadata, crypto state, and message database with `migration_session_key`.
   - Transmitted over the secure migration channel to Target.
   - Target decrypts state using `migration_session_key`.
   - Target wraps $ immediately with its own hardware **Keystore B** ({\text{device\_B}}$) and stores it into encrypted SQLite.
   - Attachments > 10MB are not transferred over QR; Target downloads ciphertext directly from media store after authentication.

5. **Two-Phase Commit (2PC)**:
   - **Phase 1 (TRANSFER & VERIFY)**: Old Device remains `ACTIVE`. New Device verifies cryptographic signatures and database integrity.
   - **Phase 2 (COMMIT)**: Target sends signed migration result to Server. Server executes an atomic database transaction:
     ```sql
     BEGIN TRANSACTION;
       UPDATE devices SET status = 'ACTIVE' WHERE device_id = target_device_id;
       UPDATE devices SET status = 'REVOKED', revoked_at = NOW() WHERE device_id = source_device_id;
       UPDATE device_migrations SET status = 'COMMITTED', committed_at = NOW() WHERE migration_id = id;
       DELETE FROM active_sessions WHERE device_id = source_device_id;
     COMMIT;
     ```
   - **Old Device Containment**: Upon receiving confirmation or next poll, Old Device enters `DEVICE_REVOKED` state and purges local application-managed sensitive keys.

---

## 7. Explicit Lifecycle State Machines

### Identity State Machine
```text
NEW ──> REGISTERING ──> ACTIVE ──> MIGRATING ──> ACTIVE
                          │
                          └──> SUSPENDED ──> CONTAINED
```

### Device State Machine
```text
PENDING ──> ACTIVE ──> MIGRATING ──> REVOKED ──> DECOMMISSIONED
```

### Migration State Machine
```text
PREPARED ──> TRANSFERRING ──> VERIFYING ──> COMMITTING ──> COMMITTED
     │              │             │              │
     └──────────────┴─────────────┴──────────────┴──────> FAILED / CANCELLED / EXPIRED
```

---

## 8. Server API Endpoints

### Identity & Devices
- `POST /identity/register` — Initial public identity registration.
- `GET /identity/me` — Retrieve identity metadata (public key, status, active devices).
- `POST /devices/register` — Register device public key and attestation chain.
- `POST /devices/challenge` — Request cryptographic nonce for device authentication.
- `POST /devices/verify` — Submit signed challenge to obtain authenticated device session.
- `POST /devices/:id/revoke` — Explicit device revocation by user or authorized backoffice.

### Migration Protocol
- `POST /migration/start` — Source device creates migration session.
- `POST /migration/:id/join` — Target device submits public ephemeral material.
- `POST /migration/:id/verify` — Confirmation of SAS and handshake proof.
- `POST /migration/:id/commit` — Transactional commit and atomic device swap.
- `POST /migration/:id/cancel` — Cancel pending migration.
- `GET /migration/:id/status` — Polling status for migration synchronization.

---

## 9. Backoffice & Audit Boundary

- **Strict Zero-Knowledge**: Backoffice administrators and APIs **never** have access to view or export Identity Private Keys or device keystore material.
- **Audit Logs Recorded**:
  - `MIGRATION_STARTED`
  - `MIGRATION_JOINED`
  - `MIGRATION_VERIFIED`
  - `MIGRATION_COMMITTED`
  - `DEVICE_REVOKED`
  - `MIGRATION_FAILED`
  - `MIGRATION_CANCELLED`
- Audit records store: `event_id`, `identity_id`, `source_device_id`, `target_device_id`, `migration_id`, timestamp, and status. No plaintext or session keys.

---

## 10. Engineering Phase Roadmap

| Phase | Scope | Deliverables |
| :--- | :--- | :--- |
| **Phase 0** | Specification & Security Architecture | `identity-spec.md`, `migration-protocol.md` |
| **Phase 1** | Cryptographic Identity & Hardware Keystore | CSPRNG 32B seed generation, Android Keystore wrapper, challenge-response auth |
| **Phase 2** | Device Lifecycle Management | Device registration, listing, revocation, and session invalidation |
| **Phase 3** | Migration Protocol & QR Handshake | QR generator, scanner, ephemeral ECDH, SAS mutual verification |
| **Phase 4** | Two-Phase Commit Migration | Atomic DB transactions, old device revocation & wiping |
| **Phase 5** | Encrypted State Transfer | Encrypted SQLCipher export/import over migration channel |
| **Phase 6** | Recovery Strategy | Strict mode (zero Central recovery) vs. secure offline split-key recovery |
| **Phase 7** | Security Audit & Penetration Testing | Keystore attestation verification, replay attacks, rooted device containment |
