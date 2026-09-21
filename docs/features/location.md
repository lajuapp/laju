# Location

Location is sensitive metadata.

Recommended modes:

- disabled
- coarse
- precise

Permissions:

```text
location.read.coarse
location.read.precise
location.export
```

Precise location should have:

- explicit policy
- short retention
- strict RBAC
- audit trail

Do not use hidden continuous tracking.
