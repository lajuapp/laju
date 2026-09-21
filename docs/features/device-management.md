# Device Management & Lifecycle

LAJU employs a **Device-Centric, Passwordless & Phone-less Cryptographic Identity** model. Devices authenticate using hardware-backed cryptographic challenge-response rather than phone numbers, SMS OTP, or email passwords.

For full technical specifications, see [`docs/protocol/identity-spec.md`](../protocol/identity-spec.md).

## Capabilities

### User Capabilities
- **Register Device**: Generate hardware-backed keystore keypair (`K_device`), wrap portable identity secret, and register public key alongside hardware model (`device_model`), operating system (`os_version`), registration location/timezone (`registration_location`), and push notification token (`push_token`).
- **Authenticate**: Authenticate sessions via cryptographic challenge-response (Sign server nonce using Keystore private key).
- **List Devices**: View active and historical devices bound to the user's identity, displaying detected device model, registration location, and notification readiness.
- **Verify Devices**: Inspect cryptographic identity keys and hardware attestation levels (TEE / StrongBox).
- **Notification Token Updates**: Dynamically sync device push notification tokens via `POST /devices/push-token`.
- **QR Device Migration**: Move identity and encrypted state securely from old device to new device using ephemeral ECDH, Short Authentication String (SAS), and Two-Phase Commit.
- **Revoke Device**: Revoke current or previous devices. Revoked devices immediately lose access and purge local sensitive keys.

### Administrative Capabilities
- View registered devices, hardware model, registration location/IP, and attestation metadata.
- Perform authorized emergency device revocation (incident containment).
- Inspect audit logs for migration events (`MIGRATION_STARTED`, `MIGRATION_COMMITTED`, `DEVICE_REVOKED`).
- **Strict Zero-Knowledge Boundary**: Administrators can NEVER view or export private keys or identity secrets.

## Device Lifecycle State Machine

```text
PENDING ──> ACTIVE ──> MIGRATING ──> REVOKED ──> DECOMMISSIONED
```

A revoked device cannot authenticate new operations or refresh sessions. Server rejects all sync, messaging, and push operations from revoked devices.
