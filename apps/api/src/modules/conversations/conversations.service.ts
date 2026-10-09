import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Optional
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

import { RedisService } from '../../infrastructure/redis/redis.service';
import { SeaweedFsService } from '../../infrastructure/seaweedfs/seaweedfs.service';
import { CreateConversationDto, AddMemberDto, ChangeMemberRoleDto, UpdateConversationDto } from './dto/conversation.dto';
import { ConversationType, ConversationRole } from '@secure-messenger/shared-types';

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    @Optional() private readonly seaweedFs?: SeaweedFsService
  ) {}

  /**
   * Resolve identifier (UUID, username with/without @, email, or phone number) to a User record
   */
  private async resolveUser(identifier: string, tx?: any): Promise<any> {
    if (!identifier || typeof identifier !== 'string') return null;
    const cleanId = identifier.trim();
    if (!cleanId || cleanId.startsWith('conv-') || cleanId.startsWith('grp-') || cleanId === 'm-you') {
      return null;
    }

    const prismaClient = tx || this.prisma;
    const cleanUsername = cleanId.startsWith('@') ? cleanId.substring(1) : cleanId;
    const digitsOnly = cleanId.replace(/\D/g, '');

    // 1. Direct match by ID (UUID only)
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cleanId);
    if (isUuid) {
      try {
        const byId = await prismaClient.user.findUnique({
          where: { id: cleanId }
        });
        if (byId) return byId;
      } catch (_) {}
    }

    // 2. Match by username (case-insensitive)
    const byUsername = await prismaClient.user.findFirst({
      where: {
        OR: [
          { username: { equals: cleanId, mode: 'insensitive' } },
          { username: { equals: cleanUsername, mode: 'insensitive' } }
        ]
      }
    });
    if (byUsername) return byUsername;

    // 3. Match by email (case-insensitive)
    if (cleanId.includes('@')) {
      const byEmail = await prismaClient.user.findFirst({
        where: { email: { equals: cleanId, mode: 'insensitive' } }
      });
      if (byEmail) return byEmail;
    }

    // 4. Match by phoneNumber
    if (digitsOnly.length >= 6) {
      const byPhone = await prismaClient.user.findFirst({
        where: {
          OR: [
            { phoneNumber: cleanId },
            { phoneNumber: `+${digitsOnly}` },
            { phoneNumber: digitsOnly },
            { phoneNumber: { contains: digitsOnly } }
          ]
        }
      });
      if (byPhone) return byPhone;
    }

    return null;
  }

  async createConversation(currentUserId: string, dto: CreateConversationDto) {
    if (!dto.participantUserIds || !Array.isArray(dto.participantUserIds) || dto.participantUserIds.length === 0) {
      throw new BadRequestException('Daftar peserta tidak boleh kosong');
    }

    // Ensure current authenticated user exists
    const currentUser = await this.prisma.user.findUnique({
      where: { id: currentUserId }
    });
    if (!currentUser) {
      throw new NotFoundException('Pengguna saat ini tidak ditemukan');
    }

    // Resolve all participant identifiers
    const resolvedParticipants: { raw: string; user: any }[] = [];
    for (const rawId of dto.participantUserIds) {
      const u = await this.resolveUser(rawId);
      resolvedParticipants.push({ raw: rawId, user: u });
    }

    if (dto.type === ConversationType.PERSONAL) {
      const target = resolvedParticipants[0];
      if (!target || !target.user) {
        throw new NotFoundException(
          `Kontak tujuan "${target?.raw || 'tidak diketahui'}" tidak ditemukan di sistem LAJU`
        );
      }

      if (target.user.id === currentUserId) {
        throw new BadRequestException('Tidak dapat membuat percakapan dengan akun sendiri');
      }

      const otherUserId = target.user.id;

      // Check if conversation already exists between these 2 users
      const existing = await this.prisma.conversation.findFirst({
        where: {
          type: 'PERSONAL',
          AND: [
            { members: { some: { userId: currentUserId, leftAt: null } } },
            { members: { some: { userId: otherUserId, leftAt: null } } }
          ]
        },
        include: {
          members: {
            include: {
              user: {
                select: { id: true, username: true, phoneNumber: true, status: true, trustScore: true }
              }
            }
          }
        }
      });

      if (existing) {
        return existing;
      }

      const allUserIds = [currentUserId, otherUserId];

      return this.prisma.$transaction(async (tx) => {
        const conv = await tx.conversation.create({
          data: {
            type: dto.type,
            title: dto.title || null
          }
        });

        // Add members with valid resolved user IDs
        for (const userId of allUserIds) {
          await tx.conversationMember.create({
            data: {
              conversationId: conv.id,
              userId,
              role: ConversationRole.MEMBER
            }
          });
        }

        // Create conversation event
        await tx.conversationEvent.create({
          data: {
            conversationId: conv.id,
            eventType: 'CONVERSATION_CREATED',
            payload: JSON.stringify({
              type: dto.type,
              creatorId: currentUserId,
              participants: allUserIds
            })
          }
        });

        return tx.conversation.findUnique({
          where: { id: conv.id },
          include: {
            members: {
              include: {
                user: {
                  select: { id: true, username: true, phoneNumber: true, status: true, trustScore: true }
                }
              }
            }
          }
        });
      });
    } else {
      // GROUP conversation
      const validMemberIds = resolvedParticipants
        .filter((p) => p.user && p.user.id !== currentUserId)
        .map((p) => p.user.id);

      const uniqueMemberIds = Array.from(new Set(validMemberIds));
      if (uniqueMemberIds.length === 0) {
        throw new BadRequestException('Minimal harus memilih 1 anggota kontak yang valid di sistem LAJU');
      }

      return this.prisma.$transaction(async (tx) => {
        const conv = await tx.conversation.create({
          data: {
            type: dto.type,
            title: dto.title || 'Grup Baru',
            description: dto.description || null,
            avatarUrl: dto.avatarUrl || null,
          }
        });

        // Add creator as OWNER
        await tx.conversationMember.create({
          data: {
            conversationId: conv.id,
            userId: currentUserId,
            role: ConversationRole.OWNER
          }
        });

        // Add other valid members
        for (const memberId of uniqueMemberIds) {
          await tx.conversationMember.create({
            data: {
              conversationId: conv.id,
              userId: memberId,
              role: ConversationRole.MEMBER
            }
          });
        }

        // Create conversation event
        await tx.conversationEvent.create({
          data: {
            conversationId: conv.id,
            eventType: 'CONVERSATION_CREATED',
            payload: JSON.stringify({
              type: dto.type,
              creatorId: currentUserId,
              title: dto.title || 'Grup Baru',
              description: dto.description || null,
              participants: [currentUserId, ...uniqueMemberIds]
            })
          }
        });

        if (dto.description && this.redis) {
          try {
            await this.redis.set(`conversation:${conv.id}:description`, dto.description);
          } catch (_) {}
        }
        if (dto.avatarUrl && this.redis) {
          try {
            await this.redis.set(`conversation:${conv.id}:avatarUrl`, dto.avatarUrl);
          } catch (_) {}
        }
        if (dto.wallpaperId && this.redis) {
          try {
            await this.redis.set(`conversation:${conv.id}:wallpaperId`, dto.wallpaperId);
          } catch (_) {}
        }
        if (dto.killPin && this.redis) {
          try {
            const hash = crypto.createHash('sha256').update(dto.killPin.trim()).digest('hex');
            await this.redis.set(`conversation:${conv.id}:killPinHash`, hash);
            const authList = [currentUserId, ...(dto.authorizedWipeUserIds || [])];
            await this.redis.set(
              `conversation:${conv.id}:authorizedWipeUserIds`,
              JSON.stringify(Array.from(new Set(authList)))
            );
          } catch (_) {}
        }

        // Notify other members via Redis event stream
        try {
          const publisher = this.redis?.getClient();
          if (publisher) {
            const payload = JSON.stringify({
              type: 'NEW_CONVERSATION',
              conversationId: conv.id,
              title: dto.title || 'Grup Baru',
              creatorId: currentUserId
            });
            for (const memberId of uniqueMemberIds) {
              publisher.publish(`user:${memberId}`, payload).catch(() => {});
            }
          }
        } catch (_) {}

        const created = await tx.conversation.findUnique({
          where: { id: conv.id },
          include: {
            members: {
              include: {
                user: {
                  select: { id: true, username: true, phoneNumber: true, status: true, trustScore: true }
                }
              }
            }
          }
        });

        return {
          ...created,
          description: dto.description || null,
          avatarUrl: dto.avatarUrl || null,
          wallpaperId: dto.wallpaperId || null,
          hasKillPin: !!dto.killPin,
          authorizedWipeUserIds: dto.killPin ? [currentUserId, ...(dto.authorizedWipeUserIds || [])] : []
        };
      });
    }
  }

  async listUserConversations(userId: string) {
    const convs = await this.prisma.conversation.findMany({
      where: {
        members: { some: { userId, leftAt: null } }
      },
      include: {
        members: {
          where: { leftAt: null },
          include: {
            user: {
              select: { id: true, username: true, phoneNumber: true, status: true, trustScore: true }
            }
          }
        },
        messages: {
          orderBy: { sequence: 'desc' },
          take: 1
        }
      }
    });

    return Promise.all(
      convs.map(async (conv) => {
        const [enrichedMembers, convAvatarUrl, purgedAt] = await Promise.all([
          Promise.all(
            conv.members.map(async (m) => {
              const [avatarUrl, about, onlineRaw] = await Promise.all([
                this.redis.get(`user:${m.userId}:avatar`),
                this.redis.get(`user:${m.userId}:about`),
                this.redis.get(`user:${m.userId}:online`),
              ]);
              return {
                ...m,
                user: {
                  ...m.user,
                  avatarUrl,
                  about: about ?? 'Available',
                  isOnline: onlineRaw === '1'
                }
              };
            })
          ),
          conv.type === 'GROUP'
            ? this.redis?.get(`conversation:${conv.id}:avatarUrl`).catch(() => null)
            : Promise.resolve(null),
          this.redis?.get(`conversation:${conv.id}:purgedAt`).catch(() => null),
        ]);
        const otherMember = conv.type === 'PERSONAL'
          ? enrichedMembers.find((m) => m.userId !== userId)
          : null;
        const convIsOnline = otherMember ? (otherMember.user as any).isOnline === true : false;

        return {
          ...conv,
          isOnline: convIsOnline,
          avatarUrl: conv.avatarUrl ?? convAvatarUrl ?? undefined,
          purgedAt: purgedAt ?? undefined,
          members: enrichedMembers
        };
      })
    );
  }

  async getConversation(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        members: {
          where: { leftAt: null },
          include: {
            user: { select: { id: true, username: true, phoneNumber: true, status: true, trustScore: true } }
          }
        }
      }
    });

    if (!conv) {
      return null;
    }

    const enrichedMembers = await Promise.all(
      conv.members.map(async (m) => {
        const [avatarUrl, about, onlineRaw] = await Promise.all([
          this.redis.get(`user:${m.userId}:avatar`),
          this.redis.get(`user:${m.userId}:about`),
          this.redis.get(`user:${m.userId}:online`),
        ]);
        return {
          ...m,
          user: {
            ...m.user,
            avatarUrl,
            about: about ?? 'Available',
            isOnline: onlineRaw === '1'
          }
        };
      })
    );

    const otherMember = conv.type === 'PERSONAL'
      ? enrichedMembers.find((m) => m.userId !== userId)
      : null;
    const convIsOnline = otherMember ? (otherMember.user as any).isOnline === true : false;

    const [description, avatarUrl, permissionsStr, wallpaperId, killPinHash, authWipeStr, purgedAt] = await Promise.all([
      this.redis?.get(`conversation:${conversationId}:description`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:avatarUrl`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:permissions`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:wallpaperId`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:killPinHash`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:authorizedWipeUserIds`).catch(() => null),
      this.redis?.get(`conversation:${conversationId}:purgedAt`).catch(() => null)
    ]);

    let permissions: any = undefined;
    if (permissionsStr) {
      try {
        permissions = JSON.parse(permissionsStr);
      } catch (_) {}
    }

    let authorizedWipeUserIds: string[] = [];
    if (authWipeStr) {
      try {
        authorizedWipeUserIds = JSON.parse(authWipeStr);
      } catch (_) {}
    }

    return {
      ...conv,
      isOnline: convIsOnline,
      description: conv.description ?? description ?? undefined,
      avatarUrl: conv.avatarUrl ?? avatarUrl ?? undefined,
      wallpaperId: wallpaperId ?? undefined,
      hasKillPin: !!killPinHash,
      authorizedWipeUserIds,
      purgedAt: purgedAt ?? undefined,
      permissions,
      members: enrichedMembers
    };
  }

  async addMember(userId: string, conversationId: string, dto: AddMemberDto) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member || (member.role !== 'OWNER' && member.role !== 'ADMIN')) {
      throw new ForbiddenException('Only owner or admin can add members');
    }

    const targetUser = await this.resolveUser(dto.userId);
    if (!targetUser) {
      throw new NotFoundException(`Pengguna "${dto.userId}" tidak ditemukan di sistem LAJU`);
    }
    const resolvedUserId = targetUser.id;

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.conversationMember.findUnique({
        where: {
          conversationId_userId: { conversationId, userId: resolvedUserId }
        }
      });

      if (existing && !existing.leftAt) {
        throw new BadRequestException('User is already a member');
      }

      if (existing && existing.leftAt) {
        await tx.conversationMember.update({
          where: { id: existing.id },
          data: { leftAt: null, role: dto.role || 'MEMBER', joinedAt: new Date() }
        });
      } else {
        await tx.conversationMember.create({
          data: {
            conversationId,
            userId: resolvedUserId,
            role: dto.role || 'MEMBER'
          }
        });
      }

      await tx.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_ADDED',
          payload: JSON.stringify({ userId: resolvedUserId, addedBy: userId })
        }
      });

      return { success: true };
    });
  }

  async leaveGroup(userId: string, conversationId: string, newOwnerUserId?: string) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new NotFoundException('Not a member');
    }

    return this.prisma.$transaction(async (tx) => {
      if (member.role === 'OWNER') {
        const otherActiveMembers = await tx.conversationMember.findMany({
          where: { conversationId, userId: { not: userId }, leftAt: null },
          orderBy: [
            { role: 'asc' }, // ADMIN comes before MEMBER alphabetically
            { joinedAt: 'asc' }
          ]
        });

        if (otherActiveMembers.length > 0) {
          const targetNewOwner = newOwnerUserId
            ? otherActiveMembers.find((m) => m.userId === newOwnerUserId) || otherActiveMembers[0]
            : otherActiveMembers[0];

          await tx.conversationMember.update({
            where: { id: targetNewOwner.id },
            data: { role: 'OWNER' }
          });

          await tx.conversationEvent.create({
            data: {
              conversationId,
              eventType: 'OWNERSHIP_TRANSFERRED',
              payload: JSON.stringify({ previousOwnerId: userId, newOwnerId: targetNewOwner.userId })
            }
          });
        }
      }

      await tx.conversationMember.update({
        where: { id: member.id },
        data: { leftAt: new Date() }
      });

      await tx.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_LEFT',
          payload: JSON.stringify({ userId })
        }
      });

      return { success: true };
    });

    try {
      const activeMembers = await this.prisma.conversationMember.findMany({
        where: { conversationId, leftAt: null },
        select: { userId: true }
      });
      const publisher = this.redis.getClient();
      if (publisher) {
        const payload = JSON.stringify({
          type: 'MEMBER_LEFT',
          conversationId,
          userId
        });
        for (const m of activeMembers) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    return { success: true };
  }

  async transferOwnership(userId: string, conversationId: string, newOwnerUserId: string) {
    const caller = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!caller || caller.role !== 'OWNER') {
      throw new ForbiddenException('Only the current group owner can transfer ownership');
    }

    if (userId === newOwnerUserId) {
      throw new BadRequestException('Cannot transfer ownership to yourself');
    }

    const target = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId: newOwnerUserId, leftAt: null }
    });
    if (!target) {
      throw new NotFoundException('Target user is not an active member of this group');
    }

    await this.prisma.$transaction([
      this.prisma.conversationMember.update({
        where: { id: caller.id },
        data: { role: 'ADMIN' }
      }),
      this.prisma.conversationMember.update({
        where: { id: target.id },
        data: { role: 'OWNER' }
      }),
      this.prisma.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'OWNERSHIP_TRANSFERRED',
          payload: JSON.stringify({ previousOwnerId: userId, newOwnerId: newOwnerUserId })
        }
      })
    ]);

    try {
      const activeMembers = await this.prisma.conversationMember.findMany({
        where: { conversationId, leftAt: null },
        select: { userId: true }
      });
      const publisher = this.redis.getClient();
      if (publisher) {
        const payload = JSON.stringify({
          type: 'OWNERSHIP_TRANSFERRED',
          conversationId,
          previousOwnerId: userId,
          newOwnerId: newOwnerUserId
        });
        for (const m of activeMembers) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    return { success: true, newOwnerId: newOwnerUserId };
  }

  async updateConversation(userId: string, conversationId: string, dto: UpdateConversationDto) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member || (member.role !== 'OWNER' && member.role !== 'ADMIN')) {
      throw new ForbiddenException('Only owner or admin can update group info');
    }

    const updateData: any = {};
    if (dto.title !== undefined) {
      updateData.title = dto.title;
    }
    if (dto.description !== undefined) {
      updateData.description = dto.description;
    }
    if (dto.avatarUrl !== undefined) {
      updateData.avatarUrl = dto.avatarUrl;
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const conv = await tx.conversation.update({
        where: { id: conversationId },
        data: updateData,
        include: {
          members: {
            where: { leftAt: null },
            include: { user: { select: { id: true, username: true, status: true } } }
          }
        }
      });

      await tx.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'CONVERSATION_UPDATED',
          payload: JSON.stringify({
            updatedBy: userId,
            title: dto.title,
            description: dto.description,
            permissions: dto.permissions
          })
        }
      });

      if (dto.description !== undefined && this.redis) {
        try {
          await this.redis.set(`conversation:${conversationId}:description`, dto.description);
        } catch (_) {}
      }
      if (dto.permissions !== undefined && this.redis) {
        try {
          await this.redis.set(`conversation:${conversationId}:permissions`, JSON.stringify(dto.permissions));
        } catch (_) {}
      }
      if (dto.avatarUrl !== undefined && this.redis) {
        try {
          if (dto.avatarUrl) {
            await this.redis.set(`conversation:${conversationId}:avatarUrl`, dto.avatarUrl);
          } else {
            await this.redis.del(`conversation:${conversationId}:avatarUrl`);
          }
        } catch (_) {}
      }
      if (dto.wallpaperId !== undefined && this.redis) {
        try {
          if (dto.wallpaperId) {
            await this.redis.set(`conversation:${conversationId}:wallpaperId`, dto.wallpaperId);
          } else {
            await this.redis.del(`conversation:${conversationId}:wallpaperId`);
          }
        } catch (_) {}
      }
      if (dto.killPin !== undefined && this.redis) {
        try {
          if (dto.killPin) {
            const hash = crypto.createHash('sha256').update(dto.killPin.trim()).digest('hex');
            await this.redis.set(`conversation:${conversationId}:killPinHash`, hash);
          } else {
            await this.redis.del(`conversation:${conversationId}:killPinHash`);
            await this.redis.del(`conversation:${conversationId}:authorizedWipeUserIds`);
          }
        } catch (_) {}
      }
      if (dto.authorizedWipeUserIds !== undefined && this.redis) {
        try {
          await this.redis.set(
            `conversation:${conversationId}:authorizedWipeUserIds`,
            JSON.stringify(dto.authorizedWipeUserIds)
          );
        } catch (_) {}
      }

      try {
        const publisher = this.redis?.getClient();
        if (publisher) {
          const payload = JSON.stringify({
            type: 'CONVERSATION_UPDATED',
            conversationId,
            title: conv.title,
            avatarUrl: dto.avatarUrl,
            description: dto.description,
            updatedBy: userId
          });
          for (const m of conv.members) {
            publisher.publish(`user:${m.userId}`, payload).catch(() => {});
          }
        }
      } catch (_) {}

      return {
        ...conv,
        description: dto.description,
        avatarUrl: dto.avatarUrl,
        permissions: dto.permissions,
        wallpaperId: dto.wallpaperId
      };
    });

    return updated;
  }

  async changeMemberRole(userId: string, conversationId: string, targetUserId: string, role: ConversationRole) {
    const caller = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!caller || (caller.role !== 'OWNER' && caller.role !== 'ADMIN')) {
      throw new ForbiddenException('Only owner or admin can manage member roles');
    }

    const target = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId: targetUserId, leftAt: null }
    });
    if (!target) {
      throw new NotFoundException('Member not found in this conversation');
    }

    if (target.role === 'OWNER' && caller.role !== 'OWNER') {
      throw new ForbiddenException('Cannot modify role of the group owner');
    }

    await this.prisma.$transaction([
      this.prisma.conversationMember.update({
        where: { id: target.id },
        data: { role }
      }),
      this.prisma.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_ROLE_CHANGED',
          payload: JSON.stringify({ targetUserId, role, changedBy: userId })
        }
      })
    ]);

    return { success: true, targetUserId, role };
  }

  async removeMember(userId: string, conversationId: string, targetUserId: string) {
    const caller = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!caller || (caller.role !== 'OWNER' && caller.role !== 'ADMIN')) {
      throw new ForbiddenException('Only owner or admin can remove members');
    }

    const target = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId: targetUserId, leftAt: null }
    });
    if (!target) {
      throw new NotFoundException('Member not found in this conversation');
    }

    if (target.role === 'OWNER') {
      throw new ForbiddenException('Cannot remove group owner');
    }

    await this.prisma.$transaction([
      this.prisma.conversationMember.update({
        where: { id: target.id },
        data: { leftAt: new Date() }
      }),
      this.prisma.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_REMOVED',
          payload: JSON.stringify({ targetUserId, removedBy: userId })
        }
      })
    ]);

    return { success: true };
  }

  async listMessages(userId: string, conversationId: string, limitStr?: string, cursorStr?: string) {
    let effectiveConversationId = conversationId;
    let member = await this.prisma.conversationMember.findFirst({
      where: { conversationId: effectiveConversationId, userId, leftAt: null }
    });

    if (!member && conversationId.startsWith('conv-')) {
      const targetIdentifier = conversationId.substring(5).trim();
      const targetUser = await this.resolveUser(targetIdentifier);
      if (targetUser && targetUser.id !== userId) {
        const otherUserId = targetUser.id;
        const existingConv = await this.prisma.conversation.findFirst({
          where: {
            type: 'PERSONAL',
            AND: [
              { members: { some: { userId, leftAt: null } } },
              { members: { some: { userId: otherUserId, leftAt: null } } }
            ]
          }
        });
        if (existingConv) {
          effectiveConversationId = existingConv.id;
          member = await this.prisma.conversationMember.findFirst({
            where: { conversationId: effectiveConversationId, userId, leftAt: null }
          });
        }
      }
    }

    if (!member) {
      if (conversationId.startsWith('conv-')) {
        return {
          conversationId,
          messages: [],
          count: 0,
          isTyping: false,
          typingUsers: []
        };
      }
      throw new ForbiddenException('Not a member of this conversation');
    }

    const limit = limitStr ? Math.min(parseInt(limitStr, 10), 100) : 50;
    const cursor = cursorStr ? parseInt(cursorStr, 10) : undefined;

    const whereClause: any = {
      conversationId: effectiveConversationId,
      OR: [
        { deletedAt: null },
        { state: 'DELETED' }
      ]
    };
    if (member?.clearedAt) {
      whereClause.createdAt = { gt: member.clearedAt };
    }
    if (cursor !== undefined) {
      whereClause.sequence = { gt: cursor };
    }

    const messages = await this.prisma.message.findMany({
      where: whereClause,
      take: limit,
      orderBy: { sequence: cursor !== undefined ? 'asc' : 'desc' },
      include: {
        senderUser: {
          select: { id: true, username: true }
        },
        reactions: {
          select: {
            id: true,
            userId: true,
            emoji: true,
            createdAt: true
          }
        },
        deliveries: {
          select: {
            deviceId: true,
            status: true,
            readAt: true,
            deliveredAt: true
          }
        }
      }
    });

    if (cursor === undefined) {
      messages.reverse();
    }

    // Check if other members are currently typing in this conversation
    let isTyping = false;
    const typingUsers: string[] = [];
    const convTyping = this.typingMap.get(effectiveConversationId);
    if (convTyping) {
      const now = Date.now();
      for (const [tUserId, tInfo] of Array.from(convTyping.entries())) {
        if (now - tInfo.timestamp > 3500) {
          convTyping.delete(tUserId);
        } else if (tUserId !== userId) {
          isTyping = true;
          if (tInfo.username) {
            typingUsers.push(tInfo.username);
          }
        }
      }
    }

    const purgedAt = await this.redis?.get(`conversation:${effectiveConversationId}:purgedAt`).catch(() => null);

    const convInfo = await this.prisma.conversation.findUnique({
      where: { id: effectiveConversationId },
      include: {
        members: {
          where: { leftAt: null },
          select: { userId: true, role: true }
        }
      }
    });

    let peerOnline = false;
    let otherUserId: string | undefined;
    if (convInfo?.type === 'PERSONAL') {
      const other = convInfo.members.find((m) => m.userId !== userId);
      if (other) {
        otherUserId = other.userId;
        const onlineRaw = await this.redis?.get(`user:${other.userId}:online`).catch(() => null);
        peerOnline = onlineRaw === '1';
      }
    }

    let groupInfo: any = undefined;
    if (convInfo?.type === 'GROUP') {
      const convAvatarUrl = await this.redis?.get(`conversation:${effectiveConversationId}:avatarUrl`).catch(() => null);
      const convDesc = await this.redis?.get(`conversation:${effectiveConversationId}:description`).catch(() => null);
      const isMember = convInfo.members.some((m) => m.userId === userId);
      const currentRole = convInfo.members.find((m) => m.userId === userId)?.role;
      groupInfo = {
        title: convInfo.title,
        description: convDesc ?? undefined,
        avatarUrl: convAvatarUrl ?? undefined,
        memberCount: convInfo.members.length,
        isMember,
        role: currentRole
      };
    }

    return {
      conversationId,
      messages,
      count: messages.length,
      isTyping,
      typingUsers,
      peerOnline,
      otherUserId,
      groupInfo,
      purgedAt: purgedAt ?? undefined
    };
  }

  private readonly typingMap = new Map<string, Map<string, { timestamp: number; username?: string }>>();

  async setTyping(userId: string, conversationId: string, isTyping: boolean) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null },
      include: { user: { select: { username: true } } }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    if (!this.typingMap.has(conversationId)) {
      this.typingMap.set(conversationId, new Map());
    }
    const convTyping = this.typingMap.get(conversationId)!;

    if (isTyping) {
      convTyping.set(userId, { timestamp: Date.now(), username: member.user?.username });
    } else {
      convTyping.delete(userId);
    }

    try {
      const publisher = this.redis.getClient();
      if (publisher) {
        const otherMembers = await this.prisma.conversationMember.findMany({
          where: { conversationId, leftAt: null, userId: { not: userId } },
          select: { userId: true }
        });
        const payload = JSON.stringify({
          type: 'TYPING',
          conversationId,
          userId,
          username: member.user?.username,
          isTyping
        });
        for (const m of otherMembers) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    return { success: true };
  }

  async deleteConversation(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId }
    });

    if (conv?.type === 'GROUP' && member.role !== 'OWNER') {
      throw new ForbiddenException('Only group owner can delete this group');
    }

    await this.prisma.conversation.delete({
      where: { id: conversationId }
    });

    return { success: true };
  }

  async destructiveWipe(userId: string, conversationId: string, pin: string) {
    if (!pin || typeof pin !== 'string') {
      throw new BadRequestException('PIN darurat wajib diisi');
    }

    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Bukan anggota dari obrolan grup ini');
    }

    const killPinHash = await this.redis?.get(`conversation:${conversationId}:killPinHash`).catch(() => null);
    if (!killPinHash) {
      throw new BadRequestException('Fitur sandi darurat belum diaktifkan pada grup ini');
    }

    // Verify authorized user: Owner is always authorized, or must be in authorizedWipeUserIds
    const authWipeStr = await this.redis?.get(`conversation:${conversationId}:authorizedWipeUserIds`).catch(() => null);
    let isAuthorized = member.role === 'OWNER';
    if (authWipeStr) {
      try {
        const list = JSON.parse(authWipeStr);
        if (Array.isArray(list) && list.includes(userId)) {
          isAuthorized = true;
        }
      } catch (_) {}
    }

    if (!isAuthorized) {
      throw new ForbiddenException('Anda tidak memiliki wewenang untuk menghancurkan riwayat grup ini');
    }

    // Verify PIN with stored hash
    const inputHash = crypto.createHash('sha256').update(pin.trim()).digest('hex');
    if (inputHash !== killPinHash) {
      throw new ForbiddenException('PIN darurat salah');
    }

    // Clean up all attachments from SeaweedFS before deleting messages
    try {
      const attachments = await this.prisma.attachment.findMany({
        where: { message: { conversationId } },
        select: { blobId: true }
      });
      if (this.seaweedFs && attachments.length > 0) {
        for (const att of attachments) {
          if (att.blobId) {
            this.seaweedFs.deleteBlob(att.blobId).catch(() => {});
          }
        }
      }
    } catch (_) {}

    // Permanently delete all messages in this conversation
    const deleteResult = await this.prisma.message.deleteMany({
      where: { conversationId }
    });

    // Create audit event
    try {
      await this.prisma.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'CONVERSATION_PURGED',
          payload: JSON.stringify({
            purgedBy: userId,
            deletedCount: deleteResult.count,
            timestamp: new Date().toISOString()
          })
        }
      });
    } catch (_) {}

    const purgedAt = new Date().toISOString();

    // Clean up Redis caches and persist purged timestamp
    if (this.redis) {
      try {
        await this.redis.del(`conversation:${conversationId}:messages`);
        await this.redis.del(`conversation:${conversationId}:lastMessage`);
        await this.redis.set(`conversation:${conversationId}:purgedAt`, purgedAt);
      } catch (_) {}
    }

    // Broadcast realtime event to all conversation members
    try {
      const publisher = this.redis?.getClient();
      if (publisher) {
        const members = await this.prisma.conversationMember.findMany({
          where: { conversationId, leftAt: null },
          select: { userId: true }
        });
        const payload = JSON.stringify({
          type: 'CONVERSATION_PURGED',
          conversationId,
          purgedBy: userId,
          timestamp: purgedAt
        });
        for (const m of members) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

      return {
        success: true,
        deletedCount: deleteResult.count,
        message: 'Seluruh riwayat obrolan grup telah dihancurkan secara permanen'
      };
    }

  async deleteGroup(userId: string, conversationId: string, pin: string) {
    if (!pin || typeof pin !== 'string') {
      throw new BadRequestException('Sandi / PIN wajib diisi');
    }

    const conv = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: {
        members: true
      }
    });

    if (!conv) {
      throw new NotFoundException('Grup tidak ditemukan');
    }

    if (conv.type !== 'GROUP') {
      throw new BadRequestException('Hanya percakapan grup yang dapat dihapus');
    }

    // Check membership and OWNER role
    const currentMember = conv.members.find((m) => m.userId === userId && m.leftAt === null);
    if (!currentMember) {
      throw new ForbiddenException('Bukan anggota dari obrolan grup ini');
    }

    if (currentMember.role !== 'OWNER') {
      throw new ForbiddenException('Hanya Pemilik Grup (Owner) yang berhak menghapus grup');
    }

    // Verify PIN: Prioritize killPinHash if set; fallback to user's twoFactorPin
    const killPinHash = await this.redis?.get(`conversation:${conversationId}:killPinHash`).catch(() => null);
    if (killPinHash) {
      const inputHash = crypto.createHash('sha256').update(pin.trim()).digest('hex');
      if (inputHash !== killPinHash) {
        throw new ForbiddenException('Sandi darurat grup salah');
      }
    } else {
      // Fallback: check user's twoFactorPin
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { twoFactorPin: true }
      });
      if (user?.twoFactorPin) {
        const storedPin = user.twoFactorPin.trim();
        let valid = false;
        if (storedPin.startsWith('$2a$') || storedPin.startsWith('$2b$')) {
          valid = await bcrypt.compare(pin.trim(), storedPin);
        } else {
          valid = storedPin === pin.trim();
        }
        if (!valid) {
          throw new ForbiddenException('PIN akun salah');
        }
      } else {
        // If no PIN has been set anywhere, check for default or require length >= 4
        if (pin.trim().length < 4) {
          throw new BadRequestException('PIN minimal 4 digit');
        }
      }
    }

    // 1. Clean up attachments from SeaweedFS
    try {
      const attachments = await this.prisma.attachment.findMany({
        where: { message: { conversationId } },
        select: { blobId: true }
      });
      if (this.seaweedFs && attachments.length > 0) {
        for (const att of attachments) {
          if (att.blobId) {
            this.seaweedFs.deleteBlob(att.blobId).catch(() => {});
          }
        }
      }
    } catch (_) {}

    // 2. Broadcast realtime GROUP_DELETED event to all active members BEFORE deleting records
    const activeMembers = conv.members.filter((m) => m.leftAt === null);
    try {
      const publisher = this.redis?.getClient();
      if (publisher) {
        const payload = JSON.stringify({
          type: 'GROUP_DELETED',
          conversationId,
          deletedBy: userId,
          timestamp: new Date().toISOString()
        });
        for (const m of activeMembers) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    // 3. Clean up Redis keys
    if (this.redis) {
      try {
        await Promise.all([
          this.redis.del(`conversation:${conversationId}:description`),
          this.redis.del(`conversation:${conversationId}:avatarUrl`),
          this.redis.del(`conversation:${conversationId}:wallpaperId`),
          this.redis.del(`conversation:${conversationId}:killPinHash`),
          this.redis.del(`conversation:${conversationId}:authorizedWipeUserIds`),
          this.redis.del(`conversation:${conversationId}:permissions`),
          this.redis.del(`conversation:${conversationId}:messages`),
          this.redis.del(`conversation:${conversationId}:lastMessage`),
          this.redis.del(`conversation:${conversationId}:purgedAt`)
        ]);
      } catch (_) {}
    }

    // 4. Cascade delete database records (messages, members, events, and conversation itself)
    await this.prisma.$transaction(async (tx) => {
      await tx.message.deleteMany({ where: { conversationId } });
      await tx.conversationMember.deleteMany({ where: { conversationId } });
      await tx.conversationEvent.deleteMany({ where: { conversationId } });
      await tx.conversationAccessGrant.deleteMany({ where: { conversationId } });
      await tx.conversation.delete({ where: { id: conversationId } });
    });

    return {
      success: true,
      message: 'Grup berhasil dihapus secara permanen untuk semua anggota'
    };
  }

  async clearChatForMe(userId: string, conversationId: string) {

    let effectiveConversationId = conversationId;
    let member = await this.prisma.conversationMember.findFirst({
      where: { conversationId: effectiveConversationId, userId, leftAt: null }
    });

    if (!member && conversationId.startsWith('conv-')) {
      const targetIdentifier = conversationId.substring(5).trim();
      const targetUser = await this.resolveUser(targetIdentifier);
      if (targetUser && targetUser.id !== userId) {
        const otherUserId = targetUser.id;
        const existingConv = await this.prisma.conversation.findFirst({
          where: {
            type: 'PERSONAL',
            AND: [
              { members: { some: { userId, leftAt: null } } },
              { members: { some: { userId: otherUserId, leftAt: null } } }
            ]
          }
        });
        if (existingConv) {
          effectiveConversationId = existingConv.id;
          member = await this.prisma.conversationMember.findFirst({
            where: { conversationId: effectiveConversationId, userId, leftAt: null }
          });
        }
      }
    }

    if (!member) {
      throw new ForbiddenException('Bukan anggota dari obrolan ini');
    }

    const now = new Date();
    await this.prisma.conversationMember.update({
      where: { id: member.id },
      data: { clearedAt: now }
    });

    return {
      success: true,
      conversationId: effectiveConversationId,
      clearedAt: now.toISOString()
    };
  }

  async clearChatForAll(userId: string, conversationId: string) {
    let effectiveConversationId = conversationId;
    let member = await this.prisma.conversationMember.findFirst({
      where: { conversationId: effectiveConversationId, userId, leftAt: null }
    });

    if (!member && conversationId.startsWith('conv-')) {
      const targetIdentifier = conversationId.substring(5).trim();
      const targetUser = await this.resolveUser(targetIdentifier);
      if (targetUser && targetUser.id !== userId) {
        const otherUserId = targetUser.id;
        const existingConv = await this.prisma.conversation.findFirst({
          where: {
            type: 'PERSONAL',
            AND: [
              { members: { some: { userId, leftAt: null } } },
              { members: { some: { userId: otherUserId, leftAt: null } } }
            ]
          }
        });
        if (existingConv) {
          effectiveConversationId = existingConv.id;
          member = await this.prisma.conversationMember.findFirst({
            where: { conversationId: effectiveConversationId, userId, leftAt: null }
          });
        }
      }
    }

    if (!member) {
      throw new ForbiddenException('Bukan anggota dari obrolan ini');
    }

    const conv = await this.prisma.conversation.findUnique({
      where: { id: effectiveConversationId }
    });
    if (!conv) {
      throw new NotFoundException('Obrolan tidak ditemukan');
    }

    if (conv.type === 'GROUP' && member.role !== 'OWNER' && member.role !== 'ADMIN') {
      throw new ForbiddenException('Hanya admin atau pemilik grup yang dapat menghapus pesan untuk semua orang');
    }

    // Clean up attachments
    try {
      const attachments = await this.prisma.attachment.findMany({
        where: { message: { conversationId: effectiveConversationId } },
        select: { blobId: true }
      });
      if (this.seaweedFs && attachments.length > 0) {
        for (const att of attachments) {
          if (att.blobId) {
            this.seaweedFs.deleteBlob(att.blobId).catch(() => {});
          }
        }
      }
    } catch (_) {}

    // Permanently delete messages
    const deleteResult = await this.prisma.message.deleteMany({
      where: { conversationId: effectiveConversationId }
    });

    const purgedAt = new Date().toISOString();

    try {
      await this.prisma.conversationEvent.create({
        data: {
          conversationId: effectiveConversationId,
          eventType: 'CONVERSATION_PURGED',
          payload: JSON.stringify({
            purgedBy: userId,
            deletedCount: deleteResult.count,
            timestamp: purgedAt
          })
        }
      });
    } catch (_) {}

    if (this.redis) {
      try {
        await this.redis.del(`conversation:${effectiveConversationId}:messages`);
        await this.redis.del(`conversation:${effectiveConversationId}:lastMessage`);
        await this.redis.set(`conversation:${effectiveConversationId}:purgedAt`, purgedAt);
      } catch (_) {}
    }

    try {
      const publisher = this.redis?.getClient();
      if (publisher) {
        const members = await this.prisma.conversationMember.findMany({
          where: { conversationId: effectiveConversationId, leftAt: null },
          select: { userId: true }
        });
        const payload = JSON.stringify({
          type: 'CONVERSATION_PURGED',
          conversationId: effectiveConversationId,
          purgedBy: userId,
          timestamp: purgedAt
        });
        for (const m of members) {
          publisher.publish(`user:${m.userId}`, payload).catch(() => {});
        }
      }
    } catch (_) {}

    return {
      success: true,
      conversationId: effectiveConversationId,
      deletedCount: deleteResult.count,
      purgedAt
    };
  }
}

