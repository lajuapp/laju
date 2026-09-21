# Dependency Rules

1. Domain has no framework dependencies.
2. Application depends on domain.
3. Infrastructure implements application ports.
4. Presentation calls use cases.
5. Next.js Backoffice never directly queries the database.
6. Browser-side JavaScript is never an authorization boundary.
7. NestJS performs final authorization.
8. Secrets never enter shared frontend packages.
9. Cryptographic private keys never enter server responses.
10. Sensitive actions are auditable.
