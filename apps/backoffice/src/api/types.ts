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
    onlineDevices?: number;
    offlineDevices?: number;
    totalConversations: number;
    totalGroups: number;
    totalMessages: number;
    messagesToday?: number;
    totalWallpapers: number;
    totalStickerPacks: number;
    totalDownloads?: number;
    downloadsToday?: number;
    onlineUsers?: number;
    communicatingUsers?: number;
    activeCalls?: number;
    totalCallsToday?: number;
    totalCalls?: number;
  };
  growth?: {
    newUsersToday: number;
    newUsersYesterday: number;
    newUsersThisWeek: number;
    newUsersPrevWeek: number;
    newUsersThisMonth: number;
    userGrowthRatePercent: number;
    dailyGrowthPercent: number;
    dau: number;
    wau: number;
    mau: number;
    stickinessRatio: number;
  };
  timeSeries?: {
    dailyRegistrations: { date: string; label: string; count: number }[];
    dailyMessages: { date: string; label: string; count: number }[];
  };
  distributions?: {
    platforms: { platform: string; count: number }[];
    appVersions: { version: string; count: number }[];
    messageTypes: { type: string; count: number }[];
  };
  trustAndSafety?: {
    pendingReportsCount: number;
    totalReportsCount: number;
    atRiskUsersCount: number;
    healthyUsersCount: number;
  };
  recentAuditLogs: AdminAuditEvent[];
}

export interface MarketingStats {
  overview: {
    totalDownloads: number;
    downloadsToday: number;
    downloadsThisWeek: number;
    downloadsThisMonth: number;
    totalUsers: number;
    newUsersToday: number;
    newUsersThisWeek: number;
    newUsersThisMonth: number;
    dauCount: number;
    conversionRatePercent: number;
    activeRetentionPercent: number;
  };
  trend: {
    date: string;
    label: string;
    downloads: number;
    registrations: number;
  }[];
  distributions: {
    deviceModels: { model: string; count: number }[];
    osVersions: { os: string; count: number }[];
    appVersions: { version: string; count: number }[];
    sources: { source: string; count: number }[];
  };
}


export interface UserItem {
  id: string;
  username: string;
  status: 'ACTIVE' | 'SUSPENDED' | 'DEACTIVATED';
  suspendedReason?: string | null;
  suspendedAt?: string | null;
  trustScore?: number;
  createdAt: string;
  updatedAt: string;
  _count: {
    devices: number;
    messages: number;
  };
}

export interface UserDetails {
  id: string;
  username: string;
  phoneNumber?: string | null;
  email?: string | null;
  status: 'ACTIVE' | 'SUSPENDED' | 'DEACTIVATED';
  suspendedReason?: string | null;
  suspendedAt?: string | null;
  trustScore: number;
  twoFactorEnabled: boolean;
  createdAt: string;
  updatedAt: string;
  devices: {
    id: string;
    name?: string | null;
    deviceModel?: string | null;
    platform?: string | null;
    osVersion?: string | null;
    appVersion?: string | null;
    registrationIp?: string | null;
    status: string;
    createdAt: string;
    lastSeenAt?: string | null;
  }[];
  counts: {
    devices: number;
    messages: number;
    conversationMembers: number;
    reportsReceived: number;
    reportsMade: number;
    sessions: number;
  };
}

export interface UserReportItem {
  id: string;
  reporterId: string;
  reportedUserId: string;
  category: 'SPAM' | 'SCAM' | 'HARASSMENT' | 'IMPERSONATION' | 'INAPPROPRIATE_CONTENT' | 'OTHER';
  reason: string;
  scoreDeduction: number;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  reviewNotes?: string | null;
  reviewedAt?: string | null;
  reviewedBy?: string | null;
  createdAt: string;
  updatedAt: string;
  reporter?: {
    id: string;
    username: string;
  };
  reportedUser?: {
    id: string;
    username: string;
    trustScore: number;
    status: string;
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
  isOnline?: boolean;
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
  mediaType?: 'TEXT' | 'IMAGE' | 'VIDEO';
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

export type TicketStatus = 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED';
export type TicketPriority = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface SupportTicketItem {
  id: string;
  ticketCode: string;
  userId: string;
  category: string;
  subject: string;
  message: string;
  appVersion?: string | null;
  status: TicketStatus;
  priority: TicketPriority;
  adminNotes?: string | null;
  responseMessage?: string | null;
  assignedToId?: string | null;
  resolvedAt?: string | null;
  createdAt: string;
  updatedAt: string;
  user?: {
    id: string;
    username: string;
    email?: string | null;
    phoneNumber?: string | null;
    trustScore?: number;
    status?: string;
  };
  assignedTo?: {
    id: string;
    name: string;
    username: string;
  } | null;
}

export interface UpdateTicketPayload {
  status?: TicketStatus;
  priority?: TicketPriority;
  adminNotes?: string;
  responseMessage?: string;
  assignedToId?: string;
}

export interface MaintenanceStats {
  totalUsers: number;
  totalDevices: number;
  totalDirectConversations: number;
  totalGroupConversations: number;
  totalMessages: number;
  totalStories: number;
  totalCalls: number;
  totalWallpapers: number;
  totalStickerPacks: number;
  totalStickers: number;
  totalAdmins: number;
}

export interface MaintenanceResetRequest {
  resetChats?: boolean;
  resetGroups?: boolean;
  resetUserStatuses?: boolean;
  resetCalls?: boolean;
  resetUserAccountStatuses?: boolean;
  wipeAllUsers?: boolean;
  reseedDefaults?: boolean;
  deleteWallpapers?: boolean;
  deleteStickers?: boolean;
  confirmationCode: string;
}

export interface MaintenanceResetResponse {
  success: boolean;
  message: string;
  results: Record<string, any>;
}

