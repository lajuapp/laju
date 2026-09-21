# Voice and Video Calls

Use WebRTC or another mature security-reviewed real-time media stack.

```text
Caller
 ↓
NestJS signaling
 ↓
STUN/TURN
 ↓
encrypted media
 ↓
Callee
```

## Signaling

Authenticate call participants and signaling messages.

## TURN

TURN may relay encrypted media. It should not have media plaintext.

## Backoffice

Default:

- call ID
- participants
- state
- duration
- connection/failure metadata

Do not expose audio/video recordings by default.

Administrative recording/interception, if ever required, must be a separately governed feature with explicit authorization and retention.
