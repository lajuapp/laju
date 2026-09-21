# Mobile Security

## Android security

Use:

- Android Keystore
- hardware-backed key protection where available
- encrypted SQLite
- biometric/device credential unlock
- secure task-switcher behavior
- `FLAG_SECURE` where appropriate
- strict TLS
- secure token/session handling
- no sensitive logs

## Private keys

Private keys remain on the device.

Never:

- upload private keys
- log private keys
- serialize private keys into analytics
- include keys in crash reports
- put keys in SharedPreferences

## Local data & Android Auto Backup Policy

- **Envelope Encryption**: The portable 32-byte identity secret ($I$) is encrypted/wrapped using the hardware-backed Android Keystore key before storage. Plaintext keys only exist in volatile memory.
- **SQLCipher**: Encrypt local SQLite database with keys derived via HKDF from the hardware keystore.
- **Android Auto Backup Exclusion**: `backup_rules.xml` must explicitly exclude application database, shared preferences holding keystore aliases, and credential caches to prevent unencrypted cloud extraction.
- **Minimization**: Plaintext message lifetime in memory should be minimized.

## Compromised device

A fully compromised/rooted endpoint cannot be made trustworthy solely through application code. The system must support device revocation and re-enrollment.
