import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  UnauthorizedException
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  RequestConversationAccessDto,
  AdminPasswordLoginDto,
  CreateAdminDto,
  UpdateAdminDto,
  CreateWallpaperDto,
  UpdateWallpaperDto,
  CreateStickerPackDto,
  UpdateStickerPackDto,
  CreateStickerItemDto
} from './dto/admin.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

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
      recentAuditLogs
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
      })
    ]);

    return {
      overview: {
        totalUsers,
        activeUsers,
        suspendedUsers,
        totalDevices,
        totalConversations,
        totalGroups,
        totalMessages,
        totalWallpapers,
        totalStickerPacks
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
        createdAt: true,
        updatedAt: true,
        _count: { select: { devices: true, messages: true } }
      }
    });
  }

  async suspendUser(userId: string) {
    return this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { status: 'SUSPENDED' }
      }),
      this.prisma.session.deleteMany({
        where: { userId }
      })
    ]);
  }

  async restoreUser(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { status: 'ACTIVE' }
    });
  }

  async listDevices() {
    return this.prisma.device.findMany({
      include: {
        user: { select: { id: true, username: true } }
      }
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

  async deleteWallpaper(id: string) {
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

  async deleteStickerItem(id: string) {
    return this.prisma.stickerItem.delete({
      where: { id }
    });
  }
}

