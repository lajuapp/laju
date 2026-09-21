# Mobile Notifications

Notifications are wakeups, not message transport.

## Device Push Token Registration
- During initial device registration (`POST /identity/register`), the client provides its hardware notification token (`pushToken`).
- Push tokens are bound to the specific physical device (`device_id`) and stored in both `devices.push_token` and the `push_devices` relay mapping.
- The client can update its push notification token at any time via `POST /devices/push-token` when tokens are rotated by the OS or FCM/APNs.

Recommended wakeup payload:

```json
{
  "type": "message_available",
  "conversation": "opaque-id"
}
```

Do not include:

- message body
- message preview
- attachment key
- private key
- sensitive location
