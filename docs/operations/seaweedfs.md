# SeaweedFS

Client encrypts attachment before upload.

```text
file
 ↓
client encryption
 ↓
encrypted blob
 ↓
NestJS
 ↓
SeaweedFS
```

Storage never receives the plaintext attachment key as ordinary metadata.
