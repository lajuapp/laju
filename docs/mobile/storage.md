# Mobile Storage

```text
Android Keystore
      ↓
database encryption key
      ↓
encrypted SQLite
      ↓
message/event/attachment metadata
```

Store:

- encrypted messages
- encrypted attachment data where locally cached
- event cursor
- device state
- conversation state

Never store unencrypted message plaintext as a long-term cache.

Securely delete application-managed encrypted data during containment according to platform capabilities.
