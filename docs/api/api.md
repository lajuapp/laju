# API Specification

## Identity & Authentication (Passwordless & Phoneless)

```text
POST /identity/register       # Initial public identity & initial device registration
GET  /identity/me             # Retrieve current identity profile & active devices
POST /devices/challenge       # Request cryptographic nonce challenge for authentication
POST /devices/verify          # Submit signed challenge to create authenticated device session
POST /devices/register        # Register a new device keypair (post-migration)
GET  /devices                 # List devices bound to current identity
POST /devices/:id/revoke      # Revoke specific device
```

## Migration (QR / Out-of-Band State Transfer)

```text
POST /migration/start         # Source device initiates migration session (generates QR payload)
POST /migration/:id/join      # Target device joins session with public ephemeral keys
POST /migration/:id/verify    # Mutual SAS confirmation & challenge verification
POST /migration/:id/commit    # Transactional 2PC commit (Atomic: New ACTIVE, Old REVOKED)
POST /migration/:id/cancel    # Abort/cancel migration session
GET  /migration/:id/status    # Poll migration session status
```

## Messaging

```text
POST /conversations/:id/messages
DELETE /messages/:id
POST /messages/:id/delivery
POST /messages/:id/read
```

## Sync

```text
GET /sync?conversation_id=...&cursor=...
```

## Calls

```text
POST /calls
POST /calls/:id/accept
POST /calls/:id/reject
POST /calls/:id/end
POST /calls/:id/signal
```

## Admin

```text
GET /admin/users
POST /admin/users/:id/suspend
POST /admin/users/:id/restore
GET /admin/devices
POST /admin/devices/:id/revoke
GET /admin/groups
GET /admin/conversations
POST /admin/conversations/:id/access-request
POST /admin/conversations/:id/access-approve
GET /admin/conversations/:id/messages
GET /admin/location
GET /admin/security-events
GET /admin/incidents
POST /admin/incidents/:id/contain
GET /admin/audit
```

All admin routes require authenticated administrative identity and server-side permission checks.
