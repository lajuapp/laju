# Key Management

Use an established audited E2EE protocol/library.

Potential mature primitives include X25519, Ed25519, HKDF and AEAD constructions such as AES-256-GCM or XChaCha20-Poly1305, subject to the selected protocol.

## Client keys

Private keys remain on device.

## Server keys

Only protocol-required public key material is stored.

Examples:

- identity public key
- signed pre-key
- one-time pre-keys

## Administrative access keys

If controlled Backoffice content access is required, its key hierarchy must be separate from normal user E2EE keys.

Never create one universal master key for every conversation.
