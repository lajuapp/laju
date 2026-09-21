# E2EE Protocol

Use an established audited E2EE protocol/library. Do not create custom cryptographic protocols.

```text
Sender plaintext
 ↓
client-side E2EE
 ↓
ciphertext
 ↓
NestJS
 ↓
recipient
 ↓
client-side decrypt
```

The backend handles delivery and lifecycle, not ordinary message decryption.

If controlled administrative access is enabled, it is an explicit additional trust path and must be isolated from normal E2EE key material.
