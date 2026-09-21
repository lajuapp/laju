# Disappearing Messages

Messages contain an expiration policy/state.

Expiration creates:

```text
MESSAGE_EXPIRED
```

Clients remove local plaintext/cache according to policy.

Server ciphertext is removed according to retention.

This is not protection against external recording.
