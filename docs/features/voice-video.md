# Voice and Video Calls Feature

LAJU provides crystal-clear, encrypted 1:1 and group voice/video calls powered by WebRTC with hardware acceleration.

---

## 1. Supported Capabilities

- **1:1 Voice Calling**: Ultra-low latency Opus audio codec with adaptive bitrate.
- **1:1 Video Calling**: VP8 / H.264 video with front/back camera toggling.
- **Group Audio & Video Calling**: Multi-party calling for collaborative groups.
- **Microphone & Speaker Toggle**: Fluid switching between earpiece, speakerphone, and Bluetooth headsets.
- **In-App Call Overlay**: Non-blocking floating PIP (Picture-in-Picture) window allowing users to continue messaging while on an active call.
- **Call History**: Searchable, paginated log of incoming, outgoing, and missed calls with duration metadata.

---

## 2. Call Permissions & OS Integration

Handled natively via `call_permission_service.dart`:
- **Microphone & Camera**: Requested lazily upon initiating or answering a call.
- **Foreground Service**: Android `FOREGROUND_SERVICE_PHONE_CALL` permission ensures calls continue without interruption when the app is backgrounded.
- **Full-Screen Intent**: Enables incoming calls to ring with a full-screen answer/decline interface even when the phone is locked.
- **Foreground Alert Suppression**: When the app is open, incoming calls display a clean top banner instead of disruptive system notifications.

See [Voice and Video Calls Protocol](../protocol/calls.md) for signaling sequence and TURN fallback rules.
