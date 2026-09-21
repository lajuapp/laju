# Incident Response

## Containment

```text
Incident
 ↓
policy engine
 ↓
affected users/devices
 ↓
suspend/revoke/lock
 ↓
application-data wipe request
 ↓
audit
```

## Automatic selection

The incident record should explicitly identify:

- affected user IDs
- affected device IDs
- trigger
- policy version
- responder
- timestamp
- actions taken

## Destructive actions

Avoid automatic irreversible account deletion from a single signal.

Preferred lifecycle:

```text
ACTIVE
 → SUSPENDED
 → CONTAINED
 → DECOMMISSIONED
```

Permanent deletion is a separately controlled operation.

## APK

Do not promise remote physical APK corruption. The application can enforce lockout and wipe application-managed encrypted data; Android package state remains under the OS.
