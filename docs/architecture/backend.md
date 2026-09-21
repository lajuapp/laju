# Backend — NestJS Modular Monolith

## Modules

```text
identity
authentication
devices
key-directory
conversations
messaging
attachments
synchronization
notifications
sessions
calls
security
incidents
admin
health
```

## Module structure

```text
module/
├── domain/
│   ├── entities/
│   ├── value-objects/
│   ├── events/
│   └── repositories/
├── application/
│   ├── use-cases/
│   └── ports/
├── infrastructure/
│   ├── persistence/
│   ├── realtime/
│   └── external/
└── presentation/
    ├── http/
    └── websocket/
```

## Rules

Controllers invoke use cases.

Use cases enforce authorization and business rules.

Infrastructure implements ports.

Domain must not depend on NestJS, Prisma, Redis, Gotify, SeaweedFS, or Next.js.

## Important use cases

Identity:
- RegisterAccount
- GetAccountProfile

Authentication:
- AuthenticateAccount
- RefreshSession
- LogoutSession

Devices:
- RegisterDevice
- ListDevices
- RevokeDevice
- RotateDeviceKeys

Key Directory:
- PublishPreKeys
- FetchPreKeyBundle
- ConsumeOneTimePreKey
- RotateSignedPreKey

Conversation:
- CreatePersonalConversation
- CreateGroupConversation
- AddGroupMember
- RemoveGroupMember
- LeaveGroup
- ChangeGroupRole
- UpdateGroupState

Messaging:
- SendEncryptedMessage
- AcknowledgeDelivery
- MarkMessageRead
- DeleteMessageForEveryone
- ExpireMessage

Sync:
- SyncConversationEvents
- ResolveSyncGap

Calls:
- CreateCall
- AcceptCall
- RejectCall
- EndCall
- ExchangeCallSignal

Admin:
- ListUsers
- SuspendUser
- RestoreUser
- ListDevices
- RevokeDevice
- ListGroups
- ManageGroupMember
- ListSecurityEvents
- RequestConversationAccess
- ApproveConversationAccess
- ReadAuthorizedConversation
- GetLocation
- ContainIncident
