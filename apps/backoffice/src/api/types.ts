export interface AdminUser {
  id: string;
  name: string;
  username: string;
  email: string;
  role: string;
  roleId: string;
  isActive: boolean;
  permissions?: string[];
  createdAt: string;
  updatedAt?: string;
  _count?: {
    sessions: number;
  };
}

export interface AdminRole {
  id: string;
  name: string;
  description?: string;
  permissions?: {
    permission: {
      slug: string;
      description?: string;
    };
  }[];
}

export interface LoginResponse {
  sessionToken: string;
  admin: AdminUser;
  permissions: string[];
  expiresAt: string;
}

export interface DashboardStats {
  overview: {
    totalUsers: number;
    activeUsers: number;
    suspendedUsers: number;
    totalDevices: number;
    totalConversations: number;
    totalGroups: number;
    totalMessages: number;
    totalWallpapers: number;
    totalStickerPacks: number;
    onlineUsers?: number;
    communicatingUsers?: number;
    activeCalls?: number;
  };
  recentAuditLogs: AdminAuditEvent[];
}

export interface UserItem {
  id: string;
  username: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'DEACTIVATED';
  suspendedReason?: string | null;
  suspendedAt?: string | null;
  createdAt: string;
  updatedAt: string;
  _count: {
    devices: number;
    messages: number;
  };
}

export interface DeviceItem {
  id: string;
  userId: string;
  user: {
    id: string;
    username: string;
  };
  status: 'ACTIVE' | 'REVOKED' | 'CONTAINED';
  lastSeenAt: string;
  createdAt: string;
}

export interface ChatWallpaperItem {
  id: string;
  name: string;
  category: 'SOLID' | 'GRADIENT' | 'PATTERN' | 'IMAGE';
  colorHex?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  isDefault: boolean;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface StickerItem {
  id: string;
  packId: string;
  name: string;
  imageUrl: string;
  emoji?: string;
  createdAt: string;
}

export interface StickerPackItem {
  id: string;
  name: string;
  description?: string;
  publisher?: string;
  coverUrl?: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  stickers: StickerItem[];
}

export interface ConversationItem {
  id: string;
  type: 'PERSONAL' | 'GROUP';
  createdAt: string;
  members: {
    user: {
      id: string;
      username: string;
    };
  }[];
  _count: {
    messages: number;
  };
}

export interface AdminAuditEvent {
  id: string;
  adminId: string;
  action: string;
  resource: string;
  resourceId?: string;
  details: string;
  ipAddress?: string;
  createdAt: string;
}

export interface SecurityEvent {
  id: string;
  type: string;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  status: 'OPEN' | 'CONTAINED' | 'RESOLVED' | 'CLOSED';
  description?: string;
  createdAt: string;
}

export interface SystemAnnouncement {
  id: string;
  title: string;
  content: string;
  type: 'INFO' | 'WARNING' | 'MAINTENANCE';
  targetType?: 'ALL' | 'SPECIFIC' | 'BULK';
  targetUserIds?: string[];
  targetUserCount?: number;
  isActive: boolean;
  mediaType?: 'TEXT' | 'IMAGE';
  mediaUrl?: string;
  backgroundColor?: string;
  actionUrl?: string;
  actionTitle?: string;
  durationHours?: number;
  expiresAt?: string;
  viewsCount?: number;
  createdAt: string;
  updatedAt: string;
}

export interface AppSystemConfig {
  id: string;
  minAndroidVersion: string;
  latestAndroidVersion: string;
  forceUpdate: boolean;
  maintenanceMode: boolean;
  maintenanceMessage?: string | null;
  apkUrl?: string | null;
  apkFilename?: string | null;
  apkSize?: number | null;
  apkSha256?: string | null;
  releaseNotes?: string | null;
  updatedAt: string;
}

