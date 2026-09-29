import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  UnauthorizedException,
  Optional
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';
import {
  RequestConversationAccessDto,
  AdminPasswordLoginDto,
  CreateAdminDto,
  UpdateAdminDto,
  CreateWallpaperDto,
  UpdateWallpaperDto,
  CreateStickerPackDto,
  UpdateStickerPackDto,
  CreateStickerItemDto,
  SuspendUserDto,
  CreateAnnouncementDto,
  UpdateAnnouncementDto,
  UpdateAppConfigDto
} from './dto/admin.dto';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly gotifyService?: GotifyService,
    @Optional() private readonly redisService?: RedisService,
    @Optional() private readonly seaweedFs?: SeaweedFsService
  ) {}

  // Password-based authentication for Backoffice
  async loginWithPassword(dto: AdminPasswordLoginDto) {
    const identifier = dto.identifier.trim();

    // Auto-bootstrap: Check if ANY admin user exists. If not, auto-create initial Super Admin!
    const adminCount = await this.prisma.adminUser.count();
    if (adminCount === 0) {
      let superRole = await this.prisma.adminRole.findUnique({
        where: { name: 'Super Admin' }
      });
      if (!superRole) {
        superRole = await this.prisma.adminRole.create({
          data: {
            name: 'Super Admin',
            description: 'Universal administrative control'
          }
        });
      }
      const salt = await bcrypt.genSalt(10);
      const hash = await bcrypt.hash('admin12345', salt);
      await this.prisma.adminUser.create({
        data: {
          username: 'admin',
          email: 'admin@laju.chat',
          name: 'System Administrator',
          passwordHash: hash,
          roleId: superRole.id,
          isActive: true
        }
      });
    }

    // Find admin by username or email
    const admin = await this.prisma.adminUser.findFirst({
      where: {
        OR: [
          { username: { equals: identifier, mode: 'insensitive' } },
          { email: { equals: identifier, mode: 'insensitive' } }
        ]
      },
      include: {
        role: {
          include: {
            permissions: {
              include: { permission: true }
            }
          }
        }
      }
    });

    if (!admin) {
      throw new UnauthorizedException('Username atau password admin salah');
    }

    if (!admin.isActive) {
      throw new ForbiddenException('Akun admin Anda telah dinonaktifkan. Hubungi Super Admin.');
    }

    const isMatch = await bcrypt.compare(dto.password, admin.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedException('Username atau password admin salah');
    }

    const sessionToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000); // 8 hours

    await this.prisma.adminSession.create({
      data: {
        adminId: admin.id,
        roleId: admin.roleId,
        tokenHash: sessionToken,
        expiresAt
      }
    });

    const permissions = admin.role.permissions.map((p) => p.permission.slug);

    return {
      sessionToken,
      admin: {
        id: admin.id,
        username: admin.username,
        email: admin.email,
        name: admin.name,
        roleId: admin.roleId,
        role: admin.role.name
      },
      permissions,
      expiresAt
    };
  }

  async getMe(adminId: string) {
    const admin = await this.prisma.adminUser.findUnique({
      where: { id: adminId },
      include: {
        role: {
          include: {
            permissions: {
              include: { permission: true }
            }
          }
        }
      }
    });

    if (!admin) {
      throw new NotFoundException('Admin user not found');
    }

    const permissions = admin.role.permissions.map((p) => p.permission.slug);

    return {
      id: admin.id,
      username: admin.username,
      email: admin.email,
      name: admin.name,
      isActive: admin.isActive,
      role: admin.role.name,
      roleId: admin.roleId,
      permissions
    };
  }

  async logout(token: string) {
    await this.prisma.adminSession.deleteMany({
      where: { tokenHash: token }
    });
    return { success: true };
  }

  // Dashboard Aggregation Stats
  async getDashboardStats() {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);

    const [
      totalUsers,
      activeUsers,
      suspendedUsers,
      totalDevices,
      totalConversations,
      totalGroups,
      totalMessages,
      totalWallpapers,
      totalStickerPacks,
      recentAuditLogs,
      onlineDevicesCount,
      activeCallsCount,
      recentMessagesCount
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { status: 'ACTIVE' } }),
      this.prisma.user.count({ where: { status: 'SUSPENDED' } }),
      this.prisma.device.count(),
      this.prisma.conversation.count(),
      this.prisma.conversation.count({ where: { type: 'GROUP' } }),
      this.prisma.message.count(),
      this.prisma.chatWallpaper.count(),
      this.prisma.stickerPack.count(),
      this.prisma.adminAuditEvent.findMany({
        orderBy: { createdAt: 'desc' },
        take: 6
      }),
      this.prisma.device.count({
        where: {
          status: 'ACTIVE',
          lastSeenAt: { gte: fiveMinutesAgo }
        }
      }),
      this.prisma.call.count({
        where: {
          state: { in: ['CONNECTED', 'RINGING', 'INITIATED'] }
        }
      }),
      this.prisma.message.count({
        where: {
          createdAt: { gte: fifteenMinutesAgo }
        }
      })
    ]);

    const onlineUsers = onlineDevicesCount;
    const offlineDevicesCount = Math.max(0, totalDevices - onlineDevicesCount);
    const communicatingUsers = (activeCallsCount * 2) + Math.min(recentMessagesCount, activeUsers);

    return {
      overview: {
        totalUsers,
        activeUsers,
        suspendedUsers,
        totalDevices,
        onlineDevices: onlineDevicesCount,
        offlineDevices: offlineDevicesCount,
        totalConversations,
        totalGroups,
        totalMessages,
        totalWallpapers,
        totalStickerPacks,
        onlineUsers,
        communicatingUsers,
        activeCalls: activeCallsCount
      },
      recentAuditLogs
    };
  }

  async createAdminSession(roleName: string, adminId: string) {
    const role = await this.prisma.adminRole.findUnique({
      where: { name: roleName },
      include: { permissions: { include: { permission: true } } }
    });

    if (!role) {
      throw new NotFoundException(`Role ${roleName} does not exist`);
    }

    const sessionToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000); // 8 hours

    await this.prisma.adminSession.create({
      data: {
        adminId,
        roleId: role.id,
        tokenHash: sessionToken,
        expiresAt
      }
    });

    return {
      sessionToken,
      role: role.name,
      adminId,
      permissions: role.permissions.map((p) => p.permission.slug),
      expiresAt
    };
  }

  async listUsers() {
    return this.prisma.user.findMany({
      select: {
        id: true,
        username: true,
        status: true,
        suspendedReason: true,
        suspendedAt: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { devices: true, messages: true } }
      }
    });
  }

  async suspendUser(userId: string, reason?: string) {
    return this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          status: 'SUSPENDED',
          suspendedReason: reason || 'Pelanggaran ketentuan layanan',
          suspendedAt: new Date()
        }
      }),
      this.prisma.session.deleteMany({
        where: { userId }
      })
    ]);
  }

  async restoreUser(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        status: 'ACTIVE',
        suspendedReason: null,
        suspendedAt: null
      }
    });
  }

  async listDevices() {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const devices = await this.prisma.device.findMany({
      include: {
        user: { select: { id: true, username: true } }
      },
      orderBy: { lastSeenAt: 'desc' }
    });

    return devices.map((d) => {
      const isOnline = d.status === 'ACTIVE' && d.lastSeenAt !== null && d.lastSeenAt >= fiveMinutesAgo;
      return {
        ...d,
        isOnline
      };
    });
  }

  async revokeDevice(deviceId: string) {
    return this.prisma.$transaction([
      this.prisma.device.update({
        where: { id: deviceId },
        data: { status: 'REVOKED' }
      }),
      this.prisma.session.deleteMany({
        where: { deviceId }
      })
    ]);
  }

  async listConversations() {
    return this.prisma.conversation.findMany({
      include: {
        members: {
          include: { user: { select: { id: true, username: true } } }
        },
        _count: { select: { messages: true } }
      }
    });
  }

  async listGroups() {
    return this.prisma.conversation.findMany({
      where: { type: 'GROUP' },
      include: {
        members: {
          include: { user: { select: { id: true, username: true } } }
        },
        _count: { select: { messages: true } }
      }
    });
  }

  // Controlled access workflow
  async requestConversationAccess(
    adminId: string,
    conversationId: string,
    dto: RequestConversationAccessDto
  ) {
    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId }
    });
    if (!conv) {
      throw new NotFoundException('Conversation not found');
    }

    const validityMinutes = dto.validityMinutes || 30;
    const expiresAt = new Date(Date.now() + validityMinutes * 60 * 1000);

    // Generate isolated key release reference (do NOT store plaintext key or derive from ciphertext)
    const keyReleaseRef = `keyref-${crypto.randomBytes(16).toString('hex')}`;

    return this.prisma.conversationAccessGrant.create({
      data: {
        conversationId,
        requestedById: adminId,
        reason: dto.reason,
        status: 'PENDING',
        expiresAt,
        keyReleaseRef
      }
    });
  }

  async approveConversationAccess(approverAdminId: string, grantId: string) {
    const grant = await this.prisma.conversationAccessGrant.findUnique({
      where: { id: grantId }
    });

    if (!grant) {
      throw new NotFoundException('Access grant request not found');
    }

    // Dual approval: Requester cannot approve their own grant
    if (grant.requestedById === approverAdminId) {
      throw new ForbiddenException('Dual approval rule: Approver must be distinct from requester');
    }

    if (grant.status !== 'PENDING') {
      throw new BadRequestException(`Grant is already ${grant.status}`);
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.conversationAccessApproval.create({
        data: {
          grantId,
          approvedById: approverAdminId
        }
      });

      return tx.conversationAccessGrant.update({
        where: { id: grantId },
        data: { status: 'APPROVED' }
      });
    });
  }

  async readAuthorizedConversationMessages(adminId: string, conversationId: string) {
    // Check for valid approved grant
    const validGrant = await this.prisma.conversationAccessGrant.findFirst({
      where: {
        conversationId,
        status: 'APPROVED',
        expiresAt: { gt: new Date() },
        OR: [
          { requestedById: adminId },
          { approvals: { some: { approvedById: adminId } } }
        ]
      }
    });

    if (!validGrant) {
      throw new ForbiddenException(
        'Controlled access required. No active approved grant found for this admin/conversation.'
      );
    }

    return this.prisma.message.findMany({
      where: { conversationId },
      orderBy: { sequence: 'asc' },
      select: {
        id: true,
        sequence: true,
        senderUserId: true,
        senderDeviceId: true,
        ciphertext: true,
        nonce: true,
        messageType: true,
        state: true,
        createdAt: true
      }
    });
  }

  async getLocationTrails() {
    return this.prisma.location.findMany({
      where: { expiresAt: { gt: new Date() } },
      include: { user: { select: { id: true, username: true } } },
      orderBy: { createdAt: 'desc' }
    });
  }

  async getSecurityEvents() {
    return this.prisma.securityEvent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100
    });
  }

  async getAuditLogs() {
    return this.prisma.adminAuditEvent.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200
    });
  }

  // ─── ADMIN TEAM MANAGEMENT ──────────────────────────────────────
  async listAdmins() {
    const admins = await this.prisma.adminUser.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        name: true,
        username: true,
        email: true,
        isActive: true,
        roleId: true,
        createdAt: true,
        updatedAt: true,
        role: {
          select: {
            id: true,
            name: true,
            description: true,
            permissions: {
              select: {
                permission: {
                  select: { slug: true, description: true }
                }
              }
            }
          }
        },
        _count: {
          select: { sessions: true }
        }
      }
    });

    return admins.map((a) => ({
      ...a,
      role: a.role.name,
      roleDetails: a.role,
      permissions: a.role.permissions.map((p) => p.permission.slug)
    }));
  }

  async listRoles() {
    return this.prisma.adminRole.findMany({
      include: {
        permissions: {
          include: { permission: true }
        }
      }
    });
  }

  async createAdmin(dto: CreateAdminDto) {
    const existing = await this.prisma.adminUser.findFirst({
      where: {
        OR: [
          { username: { equals: dto.username, mode: 'insensitive' } },
          { email: { equals: dto.email, mode: 'insensitive' } }
        ]
      }
    });

    if (existing) {
      throw new BadRequestException('Username atau email sudah digunakan admin lain');
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const created = await this.prisma.adminUser.create({
      data: {
        name: dto.name,
        username: dto.username,
        email: dto.email.toLowerCase(),
        passwordHash,
        roleId: dto.roleId,
        isActive: true
      },
      include: {
        role: true
      }
    });

    return {
      id: created.id,
      name: created.name,
      username: created.username,
      email: created.email,
      role: created.role.name,
      isActive: created.isActive,
      createdAt: created.createdAt
    };
  }

  async updateAdmin(id: string, dto: UpdateAdminDto) {
    const admin = await this.prisma.adminUser.findUnique({
      where: { id }
    });
    if (!admin) {
      throw new NotFoundException('Admin user not found');
    }

    const data: any = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.username !== undefined) data.username = dto.username;
    if (dto.email !== undefined) data.email = dto.email.toLowerCase();
    if (dto.roleId !== undefined) data.roleId = dto.roleId;
    if (dto.isActive !== undefined) data.isActive = dto.isActive;

    if (dto.password) {
      const salt = await bcrypt.genSalt(10);
      data.passwordHash = await bcrypt.hash(dto.password, salt);
    }

    return this.prisma.adminUser.update({
      where: { id },
      data,
      select: {
        id: true,
        name: true,
        username: true,
        email: true,
        isActive: true,
        role: { select: { id: true, name: true } },
        updatedAt: true
      }
    });
  }

  async deleteAdmin(id: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { id } });
    if (!admin) throw new NotFoundException('Admin not found');

    // Prevent deleting the last active Super Admin
    if (admin.username === 'admin') {
      throw new BadRequestException('Akun admin utama tidak dapat dihapus');
    }

    return this.prisma.$transaction([
      this.prisma.adminSession.deleteMany({ where: { adminId: id } }),
      this.prisma.adminUser.delete({ where: { id } })
    ]);
  }

  // ─── WALLPAPER & BACKGROUND MANAGEMENT ──────────────────────────
  async listWallpapers() {
    return this.prisma.chatWallpaper.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }]
    });
  }

  async getActiveWallpapers() {
    return this.prisma.chatWallpaper.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }]
    });
  }

  async createWallpaper(dto: CreateWallpaperDto) {
    // If set as default, unset other defaults
    if (dto.isDefault) {
      await this.prisma.chatWallpaper.updateMany({
        where: { isDefault: true },
        data: { isDefault: false }
      });
    }

    return this.prisma.chatWallpaper.create({
      data: {
        name: dto.name,
        category: dto.category || 'IMAGE',
        colorHex: dto.colorHex,
        imageUrl: dto.imageUrl,
        thumbnailUrl: dto.thumbnailUrl,
        isDefault: !!dto.isDefault,
        isActive: dto.isActive !== undefined ? dto.isActive : true,
        sortOrder: dto.sortOrder || 0
      }
    });
  }

  async updateWallpaper(id: string, dto: UpdateWallpaperDto) {
    if (dto.isDefault) {
      await this.prisma.chatWallpaper.updateMany({
        where: { isDefault: true, id: { not: id } },
        data: { isDefault: false }
      });
    }

    return this.prisma.chatWallpaper.update({
      where: { id },
      data: dto
    });
  }

  private extractBlobId(urlOrPath?: string | null): string | null {
    if (!urlOrPath) return null;
    const match = urlOrPath.match(/(?:asset-|status-|enc-|laju-)[a-zA-Z0-9_.-]+/);
    return match ? match[0] : null;
  }

  async deleteWallpaper(id: string) {
    const wp = await this.prisma.chatWallpaper.findUnique({ where: { id } });
    if (wp && wp.imageUrl) {
      const blobId = this.extractBlobId(wp.imageUrl);
      if (blobId && this.seaweedFs) {
        await this.seaweedFs.deleteBlob(blobId).catch(() => {});
      }
    }
    return this.prisma.chatWallpaper.delete({
      where: { id }
    });
  }

  // ─── STICKER PACK & STICKERS MANAGEMENT ─────────────────────────
  async listStickerPacks() {
    return this.prisma.stickerPack.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      include: {
        stickers: {
          orderBy: { createdAt: 'asc' }
        }
      }
    });
  }

  async getActiveStickerPacks() {
    return this.prisma.stickerPack.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      include: {
        stickers: {
          orderBy: { createdAt: 'asc' }
        }
      }
    });
  }

  async createStickerPack(dto: CreateStickerPackDto) {
    return this.prisma.stickerPack.create({
      data: {
        name: dto.name,
        description: dto.description,
        publisher: dto.publisher,
        coverUrl: dto.coverUrl,
        isActive: dto.isActive !== undefined ? dto.isActive : true,
        sortOrder: dto.sortOrder || 0
      }
    });
  }

  async updateStickerPack(id: string, dto: UpdateStickerPackDto) {
    return this.prisma.stickerPack.update({
      where: { id },
      data: dto
    });
  }

  async deleteStickerPack(id: string) {
    const pack = await this.prisma.stickerPack.findUnique({
      where: { id },
      include: { stickers: true }
    });
    if (pack) {
      if (pack.coverUrl) {
        const coverBlob = this.extractBlobId(pack.coverUrl);
        if (coverBlob && this.seaweedFs) {
          await this.seaweedFs.deleteBlob(coverBlob).catch(() => {});
        }
      }
      for (const stk of pack.stickers) {
        if (stk.imageUrl) {
          const stkWp = this.extractBlobId(stk.imageUrl);
          if (stkWp && this.seaweedFs) {
            await this.seaweedFs.deleteBlob(stkWp).catch(() => {});
          }
        }
      }
    }
    return this.prisma.stickerPack.delete({
      where: { id }
    });
  }

  async addStickerItem(packId: string, dto: CreateStickerItemDto) {
    const pack = await this.prisma.stickerPack.findUnique({ where: { id: packId } });
    if (!pack) throw new NotFoundException('Sticker pack not found');

    return this.prisma.stickerItem.create({
      data: {
        packId,
        name: dto.name,
        imageUrl: dto.imageUrl,
        emoji: dto.emoji
      }
    });
  }

  async addBulkStickers(packId: string, items: CreateStickerItemDto[]) {
    const pack = await this.prisma.stickerPack.findUnique({ where: { id: packId } });
    if (!pack) throw new NotFoundException('Sticker pack not found');

    if (!items || items.length === 0) {
      return { count: 0 };
    }

    const created = await this.prisma.stickerItem.createMany({
      data: items.map(item => ({
        packId,
        name: item.name,
        imageUrl: item.imageUrl,
        emoji: item.emoji || null,
      }))
    });

    return { count: created.count };
  }

  async deleteStickerItem(id: string) {
    const item = await this.prisma.stickerItem.findUnique({ where: { id } });
    if (item && item.imageUrl) {
      const blobId = this.extractBlobId(item.imageUrl);
      if (blobId && this.seaweedFs) {
        await this.seaweedFs.deleteBlob(blobId).catch(() => {});
      }
    }
    return this.prisma.stickerItem.delete({
      where: { id }
    });
  }

  // System Announcements & Push Broadcast
  async listAnnouncements() {
    const announcements = await this.prisma.systemAnnouncement.findMany({
      orderBy: { createdAt: 'desc' }
    });

    if (!this.redisService) return announcements;

    return Promise.all(
      announcements.map(async (a) => {
        let meta: any = {};
        let target: any = { targetType: 'ALL' };
        let viewsCount = 0;

        try {
          const metaStr = await this.redisService!.get(`announcement:${a.id}:meta`);
          if (metaStr) meta = JSON.parse(metaStr);
        } catch (_) {}

        try {
          const targetMeta = await this.redisService!.get(`announcement:${a.id}:target`);
          if (targetMeta) target = JSON.parse(targetMeta);
        } catch (_) {}

        try {
          viewsCount = await this.redisService!.getClient().scard(`announcement:${a.id}:views`);
        } catch (_) {}

        return { ...a, ...meta, ...target, viewsCount };
      })
    );
  }

  async getActiveAnnouncements(userId?: string) {
    const announcements = await this.prisma.systemAnnouncement.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' }
    });

    if (!userId || !this.redisService) {
      return announcements;
    }

    const filtered = await Promise.all(
      announcements.map(async (a) => {
        try {
          const targetMeta = await this.redisService!.get(`announcement:${a.id}:target`);
          if (targetMeta) {
            const parsed = JSON.parse(targetMeta);
            if (parsed.targetType === 'ALL') return a;
            if (Array.isArray(parsed.targetUserIds) && parsed.targetUserIds.includes(userId)) {
              return a;
            }
            return null;
          }
        } catch (_) {}
        return a;
      })
    );

    return filtered.filter(Boolean);
  }

  async createAnnouncement(dto: CreateAnnouncementDto) {
    const announcement = await this.prisma.systemAnnouncement.create({
      data: {
        title: dto.title,
        content: dto.content,
        type: dto.type || 'INFO',
        isActive: dto.isActive !== undefined ? dto.isActive : true
      }
    });

    const durationHours = dto.durationHours !== undefined ? dto.durationHours : 24;
    const expiresAt = durationHours > 0 ? new Date(Date.now() + durationHours * 3600 * 1000).toISOString() : null;

    if (this.redisService) {
      try {
        await this.redisService.set(
          `announcement:${announcement.id}:meta`,
          JSON.stringify({
            mediaType: dto.mediaType || 'TEXT',
            mediaUrl: dto.mediaUrl || null,
            backgroundColor: dto.backgroundColor || '#0F3E37',
            actionUrl: dto.actionUrl || null,
            actionTitle: dto.actionTitle || null,
            durationHours,
            expiresAt,
          })
        );
      } catch (_) {}
    }

    const targetType = (dto.targetType || 'ALL').toUpperCase();
    let matchedUsers: any[] = [];

    if (targetType === 'SPECIFIC' || targetType === 'BULK') {
      const rawIdentifiers = dto.targetUserIds || [];
      const cleanIdentifiers: string[] = [];

      for (const raw of rawIdentifiers) {
        if (!raw) continue;
        const trimmed = raw.trim();
        if (!trimmed) continue;
        cleanIdentifiers.push(trimmed);
        if (trimmed.startsWith('@')) {
          cleanIdentifiers.push(trimmed.substring(1));
        }
        const digits = trimmed.replace(/\D/g, '');
        if (digits.length >= 6) {
          cleanIdentifiers.push(digits);
          cleanIdentifiers.push(`+${digits}`);
        }
      }

      if (cleanIdentifiers.length > 0) {
        matchedUsers = await this.prisma.user.findMany({
          where: {
            status: 'ACTIVE',
            OR: [
              { id: { in: cleanIdentifiers } },
              { username: { in: cleanIdentifiers, mode: 'insensitive' } },
              { phoneNumber: { in: cleanIdentifiers } }
            ]
          },
          include: {
            devices: {
              where: { status: 'ACTIVE' },
              include: { pushDevices: true }
            }
          }
        });
      }
    } else {
      // ALL
      matchedUsers = await this.prisma.user.findMany({
        where: { status: 'ACTIVE' },
        include: {
          devices: {
            where: { status: 'ACTIVE' },
            include: { pushDevices: true }
          }
        }
      });
    }

    const targetUserIds = matchedUsers.map((u) => u.id);

    // Save targeting metadata in Redis
    if (this.redisService) {
      try {
        await this.redisService.set(
          `announcement:${announcement.id}:target`,
          JSON.stringify({
            targetType,
            targetUserIds,
            totalRecipients: matchedUsers.length
          })
        );
      } catch (_) {}
    }

    // Broadcast Push Notification if active
    let pushDeliveredCount = 0;
    if (dto.isActive !== false) {
      for (const user of matchedUsers) {
        // Publish to user Redis real-time channel
        if (this.redisService) {
          try {
            await this.redisService.getClient().publish(
              `user:${user.id}`,
              JSON.stringify({
                type: 'SYSTEM_ANNOUNCEMENT',
                id: announcement.id,
                title: announcement.title,
                content: announcement.content,
                announcementType: announcement.type,
                targetType,
                createdAt: announcement.createdAt
              })
            );
          } catch (_) {}
        }

        // Send Gotify/FCM push to each device
        if (this.gotifyService && user.devices) {
          for (const dev of user.devices) {
            const tokens: string[] = [];
            if (dev.pushDevices) {
              for (const pd of dev.pushDevices) {
                if (pd.clientToken) tokens.push(pd.clientToken);
              }
            }
            if (dev.pushToken && !tokens.includes(dev.pushToken)) {
              tokens.push(dev.pushToken);
            }

            if (tokens.length === 0) {
              await this.gotifyService.sendPushNotification({
                title: `[Pengumuman] ${announcement.title}`,
                message: announcement.content,
                priority: 6
              }).catch(() => {});
              pushDeliveredCount++;
            } else {
              for (const tok of tokens) {
                await this.gotifyService.sendPushNotification({
                  targetToken: tok,
                  title: `[Pengumuman] ${announcement.title}`,
                  message: announcement.content,
                  priority: 6
                }).catch(() => {});
                pushDeliveredCount++;
              }
            }
          }
        }
      }

      // If targetType is ALL, also publish to global Gotify app stream & global Redis channel
      if (targetType === 'ALL') {
        if (this.gotifyService) {
          await this.gotifyService.sendPushNotification({
            title: `[Pengumuman] ${announcement.title}`,
            message: announcement.content,
            priority: 6
          }).catch(() => {});
        }
        if (this.redisService) {
          try {
            await this.redisService.getClient().publish(
              'announcements:global',
              JSON.stringify({
                type: 'SYSTEM_ANNOUNCEMENT',
                id: announcement.id,
                title: announcement.title,
                content: announcement.content,
                announcementType: announcement.type,
                createdAt: announcement.createdAt
              })
            );
          } catch (_) {}
        }
      }
    }

    return {
      ...announcement,
      targetType,
      targetUserCount: matchedUsers.length,
      deliveredPushCount: pushDeliveredCount
    };
  }

  async updateAnnouncement(id: string, dto: UpdateAnnouncementDto) {
    const announcement = await this.prisma.systemAnnouncement.findUnique({ where: { id } });
    if (!announcement) throw new NotFoundException('Pengumuman tidak ditemukan');

    const prismaData: any = {};
    if (dto.title !== undefined) prismaData.title = dto.title;
    if (dto.content !== undefined) prismaData.content = dto.content;
    if (dto.type !== undefined) prismaData.type = dto.type;
    if (dto.isActive !== undefined) prismaData.isActive = dto.isActive;

    const updated = Object.keys(prismaData).length > 0
      ? await this.prisma.systemAnnouncement.update({
          where: { id },
          data: prismaData
        })
      : announcement;

    if (this.redisService) {
      try {
        const existingMetaStr = await this.redisService.get(`announcement:${id}:meta`);
        let meta = existingMetaStr ? JSON.parse(existingMetaStr) : {};
        if (dto.mediaType !== undefined) meta.mediaType = dto.mediaType;
        if (dto.mediaUrl !== undefined) meta.mediaUrl = dto.mediaUrl;
        if (dto.backgroundColor !== undefined) meta.backgroundColor = dto.backgroundColor;
        if (dto.actionUrl !== undefined) meta.actionUrl = dto.actionUrl;
        if (dto.actionTitle !== undefined) meta.actionTitle = dto.actionTitle;
        if (dto.durationHours !== undefined) {
          meta.durationHours = dto.durationHours;
          meta.expiresAt = dto.durationHours > 0
            ? new Date(Date.now() + dto.durationHours * 3600 * 1000).toISOString()
            : null;
        }
        await this.redisService.set(`announcement:${id}:meta`, JSON.stringify(meta));
      } catch (_) {}
    }

    return updated;
  }

  async deleteAnnouncement(id: string) {
    if (this.redisService) {
      try {
        const metaStr = await this.redisService.get(`announcement:${id}:meta`);
        if (metaStr) {
          const meta = JSON.parse(metaStr);
          if (meta.mediaUrl) {
            const blobId = this.extractBlobId(meta.mediaUrl);
            if (blobId && this.seaweedFs) {
              await this.seaweedFs.deleteBlob(blobId).catch(() => {});
            }
          }
        }
        await this.redisService.del(`announcement:${id}:meta`);
        await this.redisService.del(`announcement:${id}:target`);
        await this.redisService.del(`announcement:${id}:views`);
      } catch (_) {}
    }
    return this.prisma.systemAnnouncement.delete({
      where: { id }
    });
  }

  // App System Config
  async getAppConfig() {
    let config = await this.prisma.appSystemConfig.findUnique({
      where: { id: 'global' }
    });
    if (!config) {
      config = await this.prisma.appSystemConfig.create({
        data: {
          id: 'global',
          minAndroidVersion: '1.0.0',
          latestAndroidVersion: '1.0.0',
          forceUpdate: false,
          maintenanceMode: false,
          maintenanceMessage: 'Sistem sedang dalam pemeliharaan berkala. Silakan coba kembali beberapa saat lagi.'
        }
      });
    }
    return config;
  }

  async updateAppConfig(dto: UpdateAppConfigDto) {
    await this.getAppConfig(); // ensure exists
    return this.prisma.appSystemConfig.update({
      where: { id: 'global' },
      data: dto
    });
  }
}

