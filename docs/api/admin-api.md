# Admin & Backoffice API Specification

The Admin API powers the Next.js Backoffice (`apps/backoffice`) for operator governance, security telemetry, user moderation, content access request auditing, support ticketing, APK deployment, and system maintenance.

Every request requires an active administrative session (`AdminSession`) with explicit role-based permissions (`AdminRolePermission`). Super Admins hold root bypass authority.

---

## 1. Authentication & Session Management

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/admin/auth/login` | Authenticate admin with username & password; sets secure HTTP-only cookie | None |
| `GET` | `/admin/auth/me` | Fetch active admin identity, role, and granular permissions | Authenticated |
| `POST` | `/admin/auth/logout` | Invalidate current admin session | Authenticated |
| `POST` | `/admin/auth/change-password` | Update current administrator password | Authenticated |
| `GET` | `/admin/admins` | List registered administrators | `ADMINS_READ` |
| `POST` | `/admin/admins` | Provision new administrator account | `ADMINS_WRITE` |
| `PATCH` | `/admin/admins/:id` | Update administrator role or active state | `ADMINS_WRITE` |
| `POST` | `/admin/admins/:id/reset-password` | Reset password for an administrator | `ADMINS_WRITE` |
| `DELETE` | `/admin/admins/:id` | Remove administrator account | `ADMINS_WRITE` |
| `GET` | `/admin/roles` | List defined RBAC roles and permissions | `ADMINS_READ` |

---

## 2. Analytics, Service & Marketing Statistics

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/stats` | High-level system dashboard counts (users, groups, messages, calls) | `DASHBOARD_READ` |
| `GET` | `/admin/service-stats` | Real-time performance, message volume, active calls, and queue health | `DASHBOARD_READ` |
| `GET` | `/admin/marketing-stats` | Public portal visitor counts, download conversions, and geographical metrics | `DASHBOARD_READ` |
| `POST` | `/admin/app-config/track-download` | Log download analytics event from portal or external mirror | Public (API Key) |

---

## 3. Application System Configuration & APK Distribution

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/app-config` | Fetch active client version policies, minimum build, and maintenance status | `SYSTEM_CONFIG_READ` |
| `GET` | `/admin/app-config/public` | Public endpoint for Mobile and Portal to query current version and APK download URL | None |
| `PATCH` | `/admin/app-config` | Update minimum version, latest version, maintenance mode, or release notes | `SYSTEM_CONFIG_WRITE` |
| `POST` | `/admin/app-config/upload-apk-chunk` | Resumable chunked upload for binary Android `.apk` builds | `SYSTEM_CONFIG_WRITE` |
| `POST` | `/admin/app-config/upload-apk` | Direct upload of complete `.apk` binary file | `SYSTEM_CONFIG_WRITE` |
| `GET` | `/admin/app-config/download-apk` | Binary download endpoint streaming the hosted release APK | None |

---

## 4. User Moderation, Reports & Audit of Deleted Accounts

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/users` | Paginated search of active user identities | `USERS_READ` |
| `GET` | `/admin/users/:id/details` | View user device count, registration date, and security posture | `USERS_READ` |
| `POST` | `/admin/users/:id/suspend` | Suspend user account (terminates active sessions immediately) | `USERS_SUSPEND` |
| `POST` | `/admin/users/:id/restore` | Restore previously suspended user account | `USERS_SUSPEND` |
| `GET` | `/admin/deleted-accounts` | Audit log of self-deleted accounts with user-submitted departure reasons | `USERS_READ` |
| `GET` | `/admin/reports` | List submitted user abuse, harassment, and spam reports | `REPORTS_READ` |
| `POST` | `/admin/reports/:id/review` | Mark report reviewed, dismiss, or trigger incident containment | `REPORTS_WRITE` |

---

## 5. Customer Care & Support Tickets

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/tickets` | List user support tickets filtered by status (`OPEN`, `RESOLVED`, `CLOSED`) | `SUPPORT_READ` |
| `GET` | `/admin/tickets/:id` | View ticket details, user device environment, and discussion history | `SUPPORT_READ` |
| `PATCH` | `/admin/tickets/:id` | Add administrative response, assign agent, or resolve ticket | `SUPPORT_WRITE` |

---

## 6. Device & Key Fleet Management

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/devices` | List registered physical devices across all users | `DEVICES_READ` |
| `POST` | `/admin/devices/:id/revoke` | Administratively revoke compromised device keypair | `DEVICES_REVOKE` |

---

## 7. Media Customization: Wallpapers & Stickers

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/wallpapers` | List all curated and custom chat wallpapers | `ASSETS_READ` |
| `GET` | `/admin/wallpapers/public` | Public wallpaper list fetched by mobile clients | Authenticated User |
| `POST` | `/admin/wallpapers` | Upload new default wallpaper asset | `ASSETS_WRITE` |
| `PATCH` | `/admin/wallpapers/:id` | Update wallpaper title or category | `ASSETS_WRITE` |
| `DELETE` | `/admin/wallpapers/:id` | Remove wallpaper asset | `ASSETS_WRITE` |
| `GET` | `/admin/stickers/packs` | List curated sticker packs | `ASSETS_READ` |
| `GET` | `/admin/stickers/public` | Public sticker library fetched by mobile clients | Authenticated User |
| `POST` | `/admin/stickers/packs` | Create new sticker pack | `ASSETS_WRITE` |
| `PATCH` | `/admin/stickers/packs/:id` | Update sticker pack metadata or cover thumbnail | `ASSETS_WRITE` |
| `DELETE` | `/admin/stickers/packs/:id` | Remove entire sticker pack | `ASSETS_WRITE` |
| `POST` | `/admin/stickers/packs/:packId/stickers/bulk` | Bulk upload sticker items to pack | `ASSETS_WRITE` |
| `DELETE` | `/admin/stickers/:id` | Delete individual sticker item | `ASSETS_WRITE` |

---

## 8. System Announcements

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/announcements` | List past and active official system broadcasts | `ANNOUNCEMENTS_READ` |
| `GET` | `/admin/announcements/public` | Public announcements stream consumed by Mobile Status tab | Authenticated User |
| `POST` | `/admin/announcements` | Broadcast new system announcement (pushed to all clients via SSE) | `ANNOUNCEMENTS_WRITE` |
| `PATCH` | `/admin/announcements/:id` | Edit active announcement | `ANNOUNCEMENTS_WRITE` |
| `DELETE` | `/admin/announcements/:id` | Revoke broadcast announcement | `ANNOUNCEMENTS_WRITE` |

---

## 9. Controlled Conversation Access & Audit Trail

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/conversations` | List conversation metadata (excludes plaintext content) | `CONVERSATIONS_READ` |
| `GET` | `/admin/groups` | Filter and inspect group conversations and participant rosters | `CONVERSATIONS_READ` |
| `POST` | `/admin/conversations/:id/access-request` | Submit legal/compliance access request for conversation metadata | `ACCESS_REQUEST` |
| `POST` | `/admin/conversations/:id/access-approve` | Second-admin cryptographic approval for dual-control policy | `ACCESS_APPROVE` |
| `GET` | `/admin/conversations/:id/messages` | Access authorized metadata (under active grant) | `CONVERSATIONS_READ` |
| `GET` | `/admin/audit` | Query immutable tamper-evident operator audit logs | `AUDIT_READ` |
| `GET` | `/admin/security-events` | Real-time security telemetry (failed challenges, MITM alerts) | `SECURITY_EVENTS_READ` |

---

## 10. Database Maintenance (Development / Staging Only)

| Method | Endpoint | Description | Permission Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/admin/maintenance/stats` | View table counts and dead tuples | `SYSTEM_MAINTENANCE` |
| `POST` | `/admin/maintenance/reset` | Truncate and purge non-essential test data | `SYSTEM_MAINTENANCE` |
| `POST` | `/admin/maintenance/reseed` | Re-seed sample conversations and demo user accounts | `SYSTEM_MAINTENANCE` |
