# Gotify

Gotify is only a wakeup mechanism.

Payload:

```json
{
  "type": "message_available",
  "conversation": "opaque-id"
}
```

Never send message plaintext, location, keys, or sensitive previews.
