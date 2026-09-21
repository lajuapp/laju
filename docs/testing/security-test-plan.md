# Security Test Plan

## Mobile

- encrypted SQLite extraction test
- Keystore protection test
- no secret logs
- app lock
- task-switcher privacy
- containment command verification

## E2EE

- database contains no plaintext under normal operation
- private keys never leave device
- replay rejected
- duplicate send idempotent
- invalid signatures rejected
- key changes detected

## Backoffice

- RBAC bypass
- direct API bypass
- XSS
- CSRF
- SSRF
- CSP
- session theft
- privilege escalation
- passcode brute force
- expired access grant
- dual-approval bypass
- audit tampering

## Location

- permission enforcement
- precision enforcement
- retention expiry
- unauthorized export

## Calls

- signaling authentication
- participant authorization
- encrypted media
- TURN behavior
- revoked device during call

## Incident

- signature verification
- replay protection
- false-positive recovery
- device revocation
- local data wipe
- offline device containment behavior

Independent security review is required before high-assurance production claims.
