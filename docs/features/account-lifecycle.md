# Account Lifecycle & Data Sovereignty

In alignment with GNU AGPLv3 principles and zero-knowledge privacy guarantees, LAJU provides users with uncompromising sovereignty over their accounts, identity keys, group ownership, and conversation records.

---

## 1. Complete Account Deletion (`DELETE /users/me`)

Users have an unconditional right to permanently terminate their account at any time via **Pengaturan > Akun > Hapus Akun Saya**:
- **Structured Exit Reason**: The user can optionally submit a category reason (e.g. "Pindah ke perangkat lain", "Masalah privasi", "Jarang digunakan") with feedback notes.
- **Immediate Cryptographic Obliteration**:
  - All public keys, identity keys, prekeys, and active sessions are physically erased from PostgreSQL.
  - Active push registrations in `PushDevice` are deleted, stopping all notifications.
  - Profile avatars and status stories are purged from storage.
- **Audit Logging**: The Backoffice receives an anonymous tombstone record (`admin/deleted-accounts`) containing only the timestamp and selected reason category for statistical service improvement, without retaining private identity data.

---

## 2. Group Deletion with Security Master PIN

To prevent accidental group destruction or unauthorized group takeovers from lost phones:
- **Master PIN Verification**: Deleting a group conversation (`POST /conversations/:id/delete-group`) requires the group owner to input their security master PIN.
- **Atomic Cascading Purge**:
  - The conversation is deleted from all members' local views.
  - Group keys and member associations in `ConversationMember` are purged.
  - System event `GROUP_DELETED` is dispatched to all participant devices to clear local encrypted chat history.

---

## 3. Clear Chat & Destructive Wipe

1. **Clear Chat for Me (`POST /conversations/:id/clear-for-me`)**:
   - Clears message history strictly on the caller's local device database.
   - Updates local sequence markers so historical messages are not re-synced.
2. **Clear Chat for Everyone (`POST /conversations/:id/clear-all`)**:
   - Available to group admins or 1:1 participants.
   - Issues a server-side cryptographic wipe for all message records in the conversation.
3. **Destructive Wipe (`POST /conversations/:id/destructive-wipe`)**:
   - Emergency purge wiping conversation metadata, cryptographic ratchet state, and all associated media attachments across every participant's device.
