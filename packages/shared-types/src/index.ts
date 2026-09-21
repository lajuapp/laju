export enum UserStatus {
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  DEACTIVATED = 'DEACTIVATED'
}

export enum DeviceStatus {
  ACTIVE = 'ACTIVE',
  REVOKED = 'REVOKED',
  CONTAINED = 'CONTAINED'
}

export enum MessageType {
  TEXT = 'TEXT',
  ATTACHMENT = 'ATTACHMENT',
  CONTROL = 'CONTROL',
  LOCATION = 'LOCATION'
}

export enum MessageState {
  SENT = 'SENT',
  DELIVERED = 'DELIVERED',
  READ = 'READ',
  DELETED = 'DELETED',
  EXPIRED = 'EXPIRED'
}

export enum ConversationType {
  PERSONAL = 'PERSONAL',
  GROUP = 'GROUP'
}

export enum ConversationRole {
  OWNER = 'OWNER',
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER'
}

export enum OutboxStatus {
  PENDING = 'PENDING',
  PROCESSED = 'PROCESSED',
  FAILED = 'FAILED'
}

export enum IncidentSeverity {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL'
}

export enum IncidentStatus {
  OPEN = 'OPEN',
  CONTAINED = 'CONTAINED',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED'
}

export enum LocationPrecision {
  DISABLED = 'DISABLED',
  COARSE = 'COARSE',
  PRECISE = 'PRECISE'
}

export enum AdminPermission {
  CONVERSATION_METADATA_READ = 'conversation.metadata.read',
  CONVERSATION_CONTENT_REQUEST = 'conversation.content.request',
  CONVERSATION_CONTENT_APPROVE = 'conversation.content.approve',
  LOCATION_READ_COARSE = 'location.read.coarse',
  LOCATION_READ_PRECISE = 'location.read.precise',
  LOCATION_EXPORT = 'location.export',
  DEVICE_REVOKE = 'device.revoke',
  USER_SUSPEND = 'user.suspend',
  INCIDENT_CONTAIN_ACCOUNT = 'incident.contain.account',
  INCIDENT_CONTAIN_DEVICE = 'incident.contain.device',
  INCIDENT_WIPE_APP_DATA = 'incident.wipe.application_data',
  CALL_METADATA_READ = 'call.metadata.read',
  AUDIT_READ = 'audit.read',
  RETENTION_MANAGE = 'retention.manage',
  ADMIN_ROLE_MANAGE = 'admin_role.manage'
}

export enum CallState {
  INITIATED = 'INITIATED',
  RINGING = 'RINGING',
  CONNECTED = 'CONNECTED',
  ENDED = 'ENDED',
  REJECTED = 'REJECTED'
}

export interface PreKeyBundle {
  userId: string;
  deviceId: string;
  identityKey: string;
  signedPreKey: {
    keyId: number;
    publicKey: string;
    signature: string;
  };
  oneTimePreKey?: {
    keyId: number;
    publicKey: string;
  };
}

export interface SignalingPayload {
  callId: string;
  type: 'offer' | 'answer' | 'ice-candidate' | 'hangup';
  sdp?: string;
  candidate?: Record<string, unknown>;
  fromDeviceId: string;
  toDeviceId: string;
}

export interface GotifyWakeupPayload {
  type: 'message_available';
  conversation: string;
}
