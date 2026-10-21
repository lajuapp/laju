# App Lock & Biometric Protection

LAJU provides local device-level access control on the mobile client (`apps/mobile/lib/features/lock` and `apps/mobile/lib/core/services/biometric_service.dart`) to protect private chats from physical observation or unauthorized device access.

---

## 1. Authentication Mechanisms

Users can configure two layers of local authentication:
1. **Security Master PIN**: A 4-to-6 digit numeric passcode stored encrypted in local Android Keystore-backed storage.
2. **Biometric Unlock**: Hardware-backed biometric authentication (Fingerprint, Face Unlock, or Iris) using the platform's `local_auth` biometric provider.

---

## 2. Lock Screen Behavior (`AppLockScreen`)

When locked:
- The entire application UI is occluded by `AppLockScreen`.
- Android `FLAG_SECURE` prevents preview capture in the OS recent-apps task switcher.
- Notifications do not reveal message plaintext while locked.
- Failed attempts increment an exponential backoff timer to prevent brute-force passcode cracking.

---

## 3. Auto-Lock Timeout Policies

Users can set their auto-lock threshold under **Pengaturan > Privasi & Keamanan**:
- **Seketika (Immediately)**: Locks the moment the application is backgrounded or the screen turns off.
- **Setelah 1 Menit (After 1 minute)**: Grace period for brief app switching.
- **Setelah 5 Menit (After 5 minutes)**.
- **Setelah 15 Menit (After 15 minutes)**.

The timestamp of the last background event is tracked in memory. Upon resumption, if `now() - backgroundTimestamp > timeout`, the lock screen is immediately presented before rendering conversation screens.
