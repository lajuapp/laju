# Admin API Security

Every request includes authenticated admin context.

Authorization sequence:

```text
session
 ↓
role
 ↓
permission
 ↓
target scope
 ↓
policy
 ↓
step-up if required
 ↓
audit
 ↓
execute
```

Never trust:

- client-supplied role
- client-supplied permission
- hidden UI
- arbitrary user ID without authorization
