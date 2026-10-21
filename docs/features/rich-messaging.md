# Rich Messaging: Reactions, Stickers & Custom Wallpapers

Beyond end-to-end encrypted plaintext and attachments, LAJU supports expressive rich messaging features designed without compromising data sovereignty or privacy.

---

## 1. Message Reactions

Users can react to any message bubble with emojis:
- **Add Reaction**: Dispatched via `POST /messages/:id/reactions` with payload `{ emoji: "❤️" }`.
- **Update Reaction**: Tapping a different emoji updates the user's existing reaction record in `MessageReaction`.
- **Remove Reaction**: Tapping the same emoji removes the reaction via `DELETE /messages/:id/reactions/:emoji`.
- **Real-Time Synchronization**: Reactions are broadcast to conversation members over WebSocket / SSE and displayed stacked at the corner of the message bubble.

---

## 2. Custom Stickers

LAJU provides server-curated sticker packs without embedding third-party analytics SDKs:
- **Packs and Items**: Stored under `StickerPack` and `StickerItem`.
- **Discovery**: Mobile clients query `GET /admin/stickers/public` to load available packs.
- **Client Caching**: Sticker assets are cached locally via `laju_media_cache_manager.dart` to minimize bandwidth and allow offline sticker sending.
- **Rendering**: Rendered inline as high-resolution transparent PNG / WebP assets.

---

## 3. Chat Wallpapers

Users can customize conversation backgrounds:
- **Global or Per-Chat**: Applied either globally across all chats or customized for specific individual/group conversations.
- **Curated Wallpapers**: Queried from `GET /admin/wallpapers/public`.
- **Custom Image**: Users can pick a custom photo from device storage, stored locally on the client.
- **Legibility**: Automatic brightness reduction is applied to ensure chat text bubbles remain legible against high-contrast photos.

---

## 4. Voice Notes

Voice notes (`apps/mobile/lib/core/services/voice_note_service.dart`):
- Recorded in AAC / M4A format with real-time audio waveform visualization.
- Encrypted locally before upload via standard E2EE attachment pipeline.
- Inline audio player with speed controls (1.0x, 1.5x, 2.0x) and scrubbing.
