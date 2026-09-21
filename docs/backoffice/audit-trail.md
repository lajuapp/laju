# Audit Trail

Fields:

```text
event_id
actor_id
actor_role
permission
action
target_type
target_id
reason
request_id
timestamp
result
session_id
```

Audit records should be append-only from application perspective and protected from ordinary administrators.

Never put plaintext, private keys, passcodes, or tokens into audit records.
