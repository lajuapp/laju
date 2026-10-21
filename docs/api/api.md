# API Specification

This specification documents the complete HTTP and real-time API exposed by the LAJU backend (`apps/api`). All endpoints requiring client authentication enforce JWT bearer tokens derived from device keypair cryptographic verification.

---

## 1. Identity & Device Authentication (Passwordless & Phoneless)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/identity/register` | Register new user identity, initial master keypair, and primary device | No |
| `GET` | `/identity/me` | Retrieve profile information and bound active devices | Yes |
| `POST` | `/devices/challenge` | Request cryptographic nonce challenge for authentication | No |
| `POST` | `/devices/verify` | Submit Ed25519-signed challenge to receive JWT session token | No |
| `POST` | `/devices/register` | Register an additional device keypair (post-migration) | Yes |
| `GET` | `/devices` | List all active/revoked devices bound to identity | Yes |
| `POST` | `/devices/:id/revoke` | Revoke a specific device session and wipe its prekeys | Yes |
| `POST` | `/devices/push-token` | Register/update hardware push token (FCM / APNs) | Yes |
| `GET` | `/devices/push-stream` | **SSE stream**: Persistent real-time event streaming & catch-up replay (`?since=<ms>`) | Yes |
| `GET` | `/devices/gotify-config` | Retrieve Gotify push relay credentials | Yes |
| `POST` | `/devices/test-push` | Trigger test push notification for diagnostic verification | Yes |

---

## 2. Migration (QR / Out-of-Band State Transfer)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/migration/start` | Source device initiates migration session (generates QR payload) | Yes |
| `POST` | `/migration/:id/join` | Target device joins session with ephemeral keys | No |
| `POST` | `/migration/:id/verify` | Mutual SAS confirmation & challenge verification | Yes |
| `POST` | `/migration/:id/commit` | Transactional 2PC commit (Atomic: New ACTIVE, Old REVOKED) | Yes |
| `POST` | `/migration/:id/cancel` | Abort/cancel migration session | Yes |
| `GET` | `/migration/:id/status` | Poll migration session status | No |

---

## 3. Cryptographic Key Directory

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/keys/upload` | Upload signed prekey bundle and one-time prekeys for device | Yes |
| `GET` | `/keys/prekey-bundle/:userId` | Fetch latest active prekey bundle to establish new Olm/Megolm E2EE session | Yes |

---

## 4. Conversations

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/conversations` | Create direct (1:1) or group conversation | Yes |
| `GET` | `/conversations` | List active conversations for current user with unread counts | Yes |
| `GET` | `/conversations/:id` | Fetch conversation metadata, members, and disappearing policy | Yes |
| `PATCH` | `/conversations/:id` | Update conversation title, avatar, or disappearing message timer | Yes |
| `POST` | `/conversations/:id/members` | Add member(s) to group conversation | Yes |
| `PATCH` | `/conversations/:id/members/:targetUserId` | Promote/demote member role (`ADMIN`, `MEMBER`) | Yes |
| `DELETE` | `/conversations/:id/members/:targetUserId` | Remove member from group conversation | Yes |
| `POST` | `/conversations/:id/transfer-ownership` | Transfer group ownership to another member | Yes |
| `POST` | `/conversations/:id/leave` | Voluntarily leave group conversation | Yes |
| `POST` | `/conversations/:id/typing` | Broadcast ephemeral typing indicator to participants | Yes |
| `POST` | `/conversations/:id/clear-for-me` | Clear message history locally for caller device | Yes |
| `POST` | `/conversations/:id/clear-all` | Clear message history for all participants (Admins only) | Yes |
| `POST` | `/conversations/:id/delete-group` | Permanently delete group conversation (requires master PIN) | Yes |
| `POST` | `/conversations/:id/destructive-wipe` | Cryptographically wipe entire conversation across all devices | Yes |

---

## 5. Messaging & Rich Interactions

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/conversations/:id/messages` | Dispatch ciphertext message payload | Yes |
| `GET` | `/conversations/:id/messages` | Paginated message fetch (`?limit=50&before=<id>`) | Yes |
| `PATCH` | `/messages/:id` | Edit previously sent message ciphertext | Yes |
| `DELETE` | `/messages/:id` | Delete message for everyone (`DELETE_FOR_EVERYONE`) | Yes |
| `POST` | `/messages/:id/reactions` | Add or update emoji reaction (`{ emoji: "👍" }`) | Yes |
| `DELETE` | `/messages/:id/reactions/:emoji` | Remove emoji reaction from message | Yes |
| `POST` | `/messages/:id/delivery` | Acknowledge ciphertext receipt on recipient device | Yes |
| `POST` | `/messages/:id/read` | Mark message as read by recipient | Yes |

---

## 6. Status & Stories (Ephemeral 24-Hour Feed)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/status/upload` | Upload media asset (image/video) for status story | Yes |
| `GET` | `/status/media/:blobId` | Stream status media with HTTP byte-range support (`206 Partial Content`) | No |
| `POST` | `/status` | Create new text or media status story with privacy policy | Yes |
| `GET` | `/status/me` | Fetch active status stories posted by current user | Yes |
| `GET` | `/status/contacts` | Fetch active status stories grouped by contact | Yes |
| `GET` | `/status/official` | Fetch official system broadcasts appearing in status tab | Yes |
| `POST` | `/status/:id/view` | Mark story as viewed by current user (updates read receipts) | Yes |
| `GET` | `/status/:id/views` | Retrieve list of contacts who viewed user's story | Yes |
| `POST` | `/status/:id/react` | Send quick emoji reaction to story (dispatches DM to author) | Yes |
| `POST` | `/status/official/:id/view` | Mark official broadcast story as acknowledged | Yes |
| `DELETE` | `/status/:id` | Delete story before the 24-hour expiration | Yes |

---

## 7. Voice and Video Calls (WebRTC)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/calls` | Initiate 1:1 voice or video call | Yes |
| `POST` | `/calls/group` | Initiate group voice or video call | Yes |
| `GET` | `/calls/incoming` | Check active ringing call for caller device | Yes |
| `GET` | `/calls/:id` | Get call state, participants, and session metadata | Yes |
| `POST` | `/calls/:id/accept` | Accept incoming call invitation | Yes |
| `POST` | `/calls/:id/reject` | Reject incoming call invitation | Yes |
| `POST` | `/calls/:id/end` | Terminate call session for all participants | Yes |
| `POST` | `/calls/:id/signal` | Dispatch WebRTC signaling payload (SDP offer/answer, ICE) | Yes |
| `GET` | `/calls/:id/signals` | Long-poll or fetch pending WebRTC signals | Yes |
| `POST` | `/calls/:id/media-stream` | Establish fallback relay media stream | Yes |
| `POST` | `/calls/:id/audio-chunk` | Transmit fallback low-bandwidth audio chunk | Yes |
| `GET` | `/calls/:id/audio-chunks` | Retrieve fallback audio chunks | Yes |
| `POST` | `/calls/:id/video-frame` | Transmit fallback video frame | Yes |
| `GET` | `/calls/:id/video-frame` | Retrieve fallback video frame | Yes |
| `GET` | `/calls/history` | Paginated call history log (duration, type, missed/completed) | Yes |
| `DELETE` | `/calls/history` | Clear entire call history log for caller | Yes |
| `DELETE` | `/calls/:id` | Remove specific call entry from history | Yes |

---

## 8. Attachments & Media Blobs

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/attachments/avatar` | Upload encrypted profile or group avatar | Yes |
| `GET` | `/attachments/avatar/:blobId` | Retrieve public avatar blob | No |
| `POST` | `/attachments/:messageId` | Upload encrypted message media attachment | Yes |
| `GET` | `/attachments/:blobId` | Download encrypted message media attachment blob | Yes |

---

## 9. Users, Support & Abuse Reporting

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/users/me` | Fetch authenticated user profile and account details | Yes |
| `PATCH` | `/users/me` | Update username, display name, bio, or avatar URL | Yes |
| `DELETE` | `/users/me` | Permanently delete account with structured reason (`{ reason }`) | Yes |
| `GET` | `/users` | Search contacts by username | Yes |
| `GET` | `/users/:id` | View public user profile card and public identity key | Yes |
| `GET` | `/users/:id/trust-score` | Retrieve algorithmic trust score (anti-spam evaluation) | Yes |
| `POST` | `/users/report` | Submit abuse, spam, or harassment report against user | Yes |
| `POST` | `/users/support` | Open a customer support ticket | Yes |
| `GET` | `/users/support/my-tickets` | List user's opened support tickets and administrative replies | Yes |

---

## 10. Synchronization & Health

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/sync` | Cursor-based message and event synchronization | Yes |
| `GET` | `/health` | Service liveness, PostgreSQL, and Redis connectivity check | No |
