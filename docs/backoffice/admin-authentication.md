# Admin Authentication

- MFA mandatory
- WebAuthn/passkeys preferred
- secure HttpOnly cookie
- SameSite
- CSRF protection
- session rotation
- server-side revocation
- step-up authentication
- rate limiting
- suspicious-login detection

Do not store long-lived privileged tokens in localStorage.
