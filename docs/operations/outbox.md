# Transactional Outbox

Message transaction:

```text
BEGIN
  insert message
  insert conversation event
  insert outbox
COMMIT
```

Worker:

```text
outbox
 ↓
Redis realtime
 ↓
Gotify wakeup
```

This prevents a committed database event from disappearing because delivery infrastructure was temporarily unavailable.
