# Mobile Incident Containment

A server-side containment command must be authenticated and bound to a specific device.

Required checks:

- command signature/authentication
- target device identity
- nonce
- timestamp/expiry
- policy version

On valid containment:

```text
CONTAINED
  ↓
lock app
  ↓
stop sync
  ↓
invalidate local sessions
  ↓
revoke device credentials
  ↓
wipe application-managed encrypted data if policy requires
```

The APK itself should not be described as physically corrupted. Android package management is outside the application's guaranteed control.

False-positive recovery must be supported.
