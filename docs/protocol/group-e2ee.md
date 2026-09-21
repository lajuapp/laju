# Group E2EE

Use an established secure group protocol.

Support:

- owner/admin/member
- member add/remove
- leave
- role changes
- authenticated group state
- key/state rotation on membership changes

Removed members must not receive future group cryptographic state.

New members should not automatically gain historical plaintext.
