# Database Schema

Core:

```text
users
devices
device_keys
pre_keys
sessions
conversations
conversation_members
messages
message_deliveries
conversation_events
attachments
push_devices
security_events
outbox_events
calls
call_participants
incidents
incident_targets
admin_sessions
admin_roles
admin_permissions
admin_role_permissions
admin_audit_events
conversation_access_grants
conversation_access_approvals
retention_policies
locations
```

## Message

```text
id
conversation_id
sender_device_id
client_message_id
sequence
ciphertext
nonce
message_type
state
created_at
deleted_at
expires_at
```

Unique:

```text
(sender_device_id, client_message_id)
```

Index:

```text
(conversation_id, sequence)
```

## Location

Use precision class and retention expiry.

## Conversation access

Store authorization metadata, grant status, expiry, approvers, and references to protected key-release operations.

Do not store plaintext access secrets.
