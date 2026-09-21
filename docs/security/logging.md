# Secure Logging

Never log:

- passwords
- access/refresh tokens
- private keys
- message plaintext
- group secrets
- attachment keys
- MFA secrets
- conversation access passcodes

Use request IDs, opaque IDs, event type, timestamp, and result.

Logs themselves require access control and retention.
