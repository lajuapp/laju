import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { CreateConversationDto, AddMemberDto, ChangeMemberRoleDto, UpdateConversationDto } from './dto/conversation.dto';
import { ConversationType, ConversationRole } from '@secure-messenger/shared-types';

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService
  ) {}

  async createConversation(currentUserId: string, dto: CreateConversationDto) {
    const allUserIds = Array.from(new Set([currentUserId, ...dto.participantUserIds]));

    if (dto.type === ConversationType.PERSONAL) {
      if (allUserIds.length !== 2) {
        throw new BadRequestException('Personal conversation requires exactly two participants');
      }

      // Check if conversation already exists between these 2 users
      const existing = await this.prisma.conversation.findFirst({
        where: {
          type: 'PERSONAL',
          AND: [
            { members: { some: { userId: allUserIds[0] } } },
            { members: { some: { userId: allUserIds[1] } } }
          ]
        },
        include: { members: true }
      });

      if (existing) {
        return existing;
      }
    }

    return this.prisma.$transaction(async (tx) => {
      const conv = await tx.conversation.create({
        data: {
          type: dto.type,
          title: dto.title || null
        }
      });

      // Add members
      for (const userId of allUserIds) {
        const isCreator = userId === currentUserId;
        const role =
          dto.type === ConversationType.GROUP && isCreator
            ? ConversationRole.OWNER
            : ConversationRole.MEMBER;

        await tx.conversationMember.create({
          data: {
            conversationId: conv.id,
            userId,
            role
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
        include: { members: true }
      });
    });
  }

  async listUserConversations(userId: string) {
    const convs = await this.prisma.conversation.findMany({
      where: {
        members: { some: { userId, leftAt: null } }
      },
      include: {
        members: {
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
        const enrichedMembers = await Promise.all(
          conv.members.map(async (m) => {
            const [avatarUrl, about] = await Promise.all([
              this.redis.get(`user:${m.userId}:avatar`),
              this.redis.get(`user:${m.userId}:about`),
            ]);
            return {
              ...m,
              user: {
                ...m.user,
                avatarUrl,
                about: about ?? 'Available'
              }
            };
          })
        );
        return {
          ...conv,
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
        const [avatarUrl, about] = await Promise.all([
          this.redis.get(`user:${m.userId}:avatar`),
          this.redis.get(`user:${m.userId}:about`),
        ]);
        return {
          ...m,
          user: {
            ...m.user,
            avatarUrl,
            about: about ?? 'Available'
          }
        };
      })
    );

    return {
      ...conv,
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

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.conversationMember.findUnique({
        where: {
          conversationId_userId: { conversationId, userId: dto.userId }
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
            userId: dto.userId,
            role: dto.role || 'MEMBER'
          }
        });
      }

      await tx.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_ADDED',
          payload: JSON.stringify({ userId: dto.userId, addedBy: userId })
        }
      });

      return { success: true };
    });
  }

  async leaveGroup(userId: string, conversationId: string) {
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new NotFoundException('Not a member');
    }

    await this.prisma.$transaction([
      this.prisma.conversationMember.update({
        where: { id: member.id },
        data: { leftAt: new Date() }
      }),
      this.prisma.conversationEvent.create({
        data: {
          conversationId,
          eventType: 'MEMBER_LEFT',
          payload: JSON.stringify({ userId })
        }
      })
    ]);

    return { success: true };
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

      return conv;
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
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    const limit = limitStr ? Math.min(parseInt(limitStr, 10), 100) : 50;
    const cursor = cursorStr ? parseInt(cursorStr, 10) : undefined;

    const whereClause: any = {
      conversationId,
      deletedAt: null
    };
    if (cursor !== undefined) {
      whereClause.sequence = { gt: cursor };
    }

    const messages = await this.prisma.message.findMany({
      where: whereClause,
      take: limit,
      orderBy: { sequence: 'asc' },
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
        }
      }
    });

    // Check if other members are currently typing in this conversation
    let isTyping = false;
    const typingUsers: string[] = [];
    const convTyping = this.typingMap.get(conversationId);
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

    return {
      conversationId,
      messages,
      count: messages.length,
      isTyping,
      typingUsers
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
}
