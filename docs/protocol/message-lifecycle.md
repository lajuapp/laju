# Message Lifecycle

1. Client encrypts.
2. API authenticates device.
3. API validates lifecycle and idempotency.
4. PostgreSQL transaction writes message.
5. Transaction writes conversation event.
6. Transaction writes outbox event.
7. Worker publishes Redis realtime.
8. Worker sends generic Gotify wakeup.
9. Recipient syncs by cursor.
10. Recipient decrypts locally.
