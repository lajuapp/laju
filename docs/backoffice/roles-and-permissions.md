# Roles and Permissions

Roles:

- Super Admin
- Security Admin
- User Admin
- Device Admin
- Group Admin
- Conversation Investigator
- Operations
- Auditor
- Read-only Analyst

Sensitive permissions:

```text
conversation.metadata.read
conversation.content.request
conversation.content.approve
location.read.coarse
location.read.precise
device.revoke
user.suspend
incident.contain.account
incident.contain.device
incident.wipe.application_data
call.metadata.read
audit.read
retention.manage
admin_role.manage
```

Do not use broad wildcard permissions by default.
