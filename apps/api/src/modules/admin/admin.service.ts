import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RequestConversationAccessDto } from './dto/admin.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

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
}
