# Backoffice Security — Next.js

## Security boundary

```text
Browser
  ↓ HTTPS
Next.js
  ↓
NestJS Admin API
  ↓
Authorization
  ↓
Use Case
  ↓
Audit
  ↓
Database
```

The browser is not trusted.

## Authentication

Required:

- MFA
- preferably WebAuthn/passkeys for privileged accounts
- secure HttpOnly cookies
- SameSite
- CSRF protection where cookie-authenticated mutations are used
- short-lived sessions
- session rotation
- server-side revocation
- re-authentication for critical operations

Do not put long-lived privileged tokens in localStorage.

## Next.js

- protected layouts/routes
- server-side session validation
- strict input validation
- CSP
- HSTS
- X-Content-Type-Options
- Referrer-Policy
- Permissions-Policy
- frame-ancestors restriction
- no debug stack traces in production
- no secrets in `NEXT_PUBLIC_*`
- no unsafe dynamic HTML
- SSRF protection for server-side URL fetching
- upload validation and limits
- dependency scanning

Middleware is an early gate, not the final authorization layer.

## Data exposure

Only return the minimum required fields.

Do not expose:

- private keys
- session secrets
- passwords
- MFA secrets
- attachment decryption keys

## Admin access to conversations

Use separate authorization and a per-conversation access secret.

```text
Admin
 ↓
MFA
 ↓
permission
 ↓
conversation access request
 ↓
step-up auth
 ↓
optional second approver
 ↓
access secret release
 ↓
time-limited read-only session
 ↓
audit
```

## Compromised Backoffice

A compromised Backoffice must not automatically expose:

- client private keys
- all conversation plaintext
- all precise location
- all attachment keys

This requires a separate protected access-secret boundary.

## Headers

Use restrictive production security headers and a strong CSP without unsafe broad script allowances.
