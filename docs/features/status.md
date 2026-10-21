# Status & Ephemeral Stories

LAJU includes an ephemeral status and stories feature (`apps/mobile/lib/features/status` and `apps/api/src/modules/status`), allowing users to share updates that self-destruct after 24 hours.

---

## 1. Lifecycle & Auto-Expiration

- **24-Hour TTL**: Each status story record in `UserStatusStory` has an `expiresAt` timestamp set to `createdAt + 24 hours`.
- **Automated Purging**: Expired stories are automatically filtered from contacts' feeds and periodically purged from storage.
- **Manual Deletion**: Authors can manually delete a story at any time via `DELETE /status/:id`, triggering immediate deletion of media assets from SeaweedFS.

---

## 2. Media Types & Video Range Streaming

1. **Text Status**:
   - Custom background color gradient.
   - Rich typography with emoji support.
2. **Photo Status**:
   - Direct capture from camera (`camera_status_screen.dart`) or selection from gallery.
   - Client-side compression before encrypted upload.
3. **Video Status**:
   - Up to 30-second clips (`video_status_composer_screen.dart`).
   - Served via `GET /status/media/:blobId` with HTTP **206 Partial Content** byte-range streaming (`Range: bytes=start-end`), enabling instant seeking and buffer-free playback on low-bandwidth networks.

---

## 3. Privacy Controls

Users control story distribution via three distinct privacy settings (`status_privacy_contact_picker_screen.dart`):
- **Semua Kontak (All Contacts)**: Visible to all established mutual contacts.
- **Kontak Saya Kecuali... (My Contacts Except...)**: Blacklist mode hiding status from specific contacts.
- **Hanya Bagikan Ke... (Only Share With...)**: Whitelist mode sharing status exclusively with selected individuals.

---

## 4. Read Receipts & Quick Reactions

- **Viewer List**: When a contact views a story, a `StatusStoryView` record is created via `POST /status/:id/view`. The author can view real-time reader profiles and timestamps (`GET /status/:id/views`).
- **Quick Reactions**: Viewers can tap quick reaction emojis (`POST /status/:id/react`). The server dispatches the reaction as a direct message in the 1:1 conversation between viewer and author.

---

## 5. Official System Announcements

System announcements broadcasted from the Backoffice (`SystemAnnouncement`) appear prominently at the top of the Status feed:
- Highlighted with an official badge.
- Pushed in real time via SSE channel `announcements:global`.
- Acknowledged via `POST /status/official/:id/view`.
