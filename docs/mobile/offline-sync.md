# Offline Sync

Mobile keeps a local event cursor.

Example:

```text
100 MESSAGE_CREATED
101 MESSAGE_CREATED
102 MESSAGE_DELETED
103 MESSAGE_CREATED
```

On reconnect:

```text
GET /sync?cursor=103
```

If the client receives sequence 105 while expecting 104:

```text
gap detected
→ request missing events
→ apply events transactionally
→ advance cursor
```

Local event application and cursor update must be atomic.
