# Controlled Administrative Conversation Access

## Requirement

Backoffice can be permitted to inspect personal/group messages only through a controlled exceptional-access workflow.

## Critical cryptographic rule

Do not derive a passcode from ciphertext.

A passcode generated deterministically from encrypted text would mean database/ciphertext compromise could weaken the second layer.

Instead:

```text
Cryptographically random conversation secret
        ↓
protected key-release boundary
        ↓
human-friendly passcode/verifier if required
```

The passcode must be:

- independent
- rate-limited
- never logged
- not in push payloads
- time-limited
- protected by MFA/step-up authentication

## High assurance

For sensitive conversations:

```text
Admin A requests
 ↓
Policy check
 ↓
Admin B approval
 ↓
MFA
 ↓
temporary access
 ↓
read-only content
 ↓
automatic expiry
 ↓
audit
```

Never build a universal administrator master key.
