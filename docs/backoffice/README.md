# Next.js Backoffice

## Pages

```text
/dashboard
/users
/devices
/groups
/conversations
/calls
/security-events
/incidents
/location
/audit
/retention
/admin-access
/settings
```

Backoffice is a web administrative console and never directly accesses the database.

## Conversation view

Personal and group conversations may be visible according to permission.

The UI must clearly distinguish:

- metadata access
- requested content access
- approved content access
- expired content access

Every content-access operation is auditable.
