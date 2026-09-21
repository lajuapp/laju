# Delete for Everyone

Use:

```text
ACTIVE → DELETED
```

Transaction:

```text
authorize
→ update state
→ MESSAGE_DELETED event
→ outbox event
→ commit
```

Offline devices receive the deletion through synchronization.

Physical purge follows retention policy.

Deletion cannot guarantee removal from screenshots, recordings, copied text, or compromised devices.
