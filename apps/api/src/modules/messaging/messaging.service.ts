import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
  Optional
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { SendMessageDto } from './dto/message.dto';

@Injectable()
export class MessagingService {
  private readonly logger = new Logger(MessagingService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly redisService?: RedisService,
    @Optional() private readonly gotifyService?: GotifyService
  ) {}

  private async getValidDeviceId(userId: string, requestedDeviceId?: string): Promise<string> {
    if (requestedDeviceId) {
      try {
        const existing = await this.prisma?.device?.findFirst({
          where: { id: requestedDeviceId }
        });
        if (existing) {
          if (existing.userId !== userId) {
            await this.prisma?.device?.update({
              where: { id: existing.id },
              data: { userId, status: 'ACTIVE', lastSeenAt: new Date() }
            });
          }
          return existing.id;
        }
      } catch (_) {}
    }

    try {
      const anyActive = await this.prisma?.device?.findFirst({
        where: { userId, status: 'ACTIVE' },
        orderBy: { lastSeenAt: 'desc' }
      });
      if (anyActive) return anyActive.id;
    } catch (_) {}

    try {
      const anyDevice = await this.prisma?.device?.findFirst({
        where: { userId },
        orderBy: { createdAt: 'desc' }
      });
      if (anyDevice) return anyDevice.id;
    } catch (_) {}

    try {
      if (this.prisma?.device?.create) {
        const newDevice = await this.prisma.device.create({
          data: {
            userId,
            deviceUuid: `dev-${userId.substring(0, 8)}-${Date.now()}`,
            name: 'Mobile Device',
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
        return newDevice.id;
      }
    } catch (_) {}

    return requestedDeviceId || `dev-${userId.substring(0, 8)}`;
  }

  async sendMessage(
    userId: string,
    deviceId: string,
    conversationId: string,
    dto: SendMessageDto
  ) {
    let effectiveConversationId = conversationId;

    // 1. Verify user membership
    let member = await this.prisma.conversationMember.findFirst({
      where: { conversationId: effectiveConversationId, userId, leftAt: null }
    });

    if (!member && conversationId.startsWith('conv-')) {
      const targetIdentifier = conversationId.substring(5).trim();
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetIdentifier);
      const cleanUsername = targetIdentifier.startsWith('@') ? targetIdentifier.substring(1) : targetIdentifier;
      const digitsOnly = targetIdentifier.replace(/\D/g, '');

      let targetUser: any = null;
      if (isUuid) {
        try {
          targetUser = await this.prisma.user.findUnique({ where: { id: targetIdentifier } });
        } catch (_) {}
      }
      if (!targetUser) {
        targetUser = await this.prisma.user.findFirst({
          where: {
            OR: [
              { username: { equals: targetIdentifier, mode: 'insensitive' as const } },
              { username: { equals: cleanUsername, mode: 'insensitive' as const } },
              ...(targetIdentifier.includes('@') ? [{ email: { equals: targetIdentifier, mode: 'insensitive' as const } }] : []),
              ...(digitsOnly.length >= 6 ? [
                { phoneNumber: targetIdentifier },
                { phoneNumber: `+${digitsOnly}` },
                { phoneNumber: digitsOnly },
                { phoneNumber: { contains: digitsOnly } }
              ] : [])
            ]
          }
        });
      }

      if (targetUser && targetUser.id !== userId) {
        const otherUserId = targetUser.id;
        let existingConv = await this.prisma.conversation.findFirst({
          where: {
            type: 'PERSONAL',
            AND: [
              { members: { some: { userId, leftAt: null } } },
              { members: { some: { userId: otherUserId, leftAt: null } } }
            ]
          }
        });

        if (!existingConv) {
          existingConv = await this.prisma.conversation.create({
            data: {
              type: 'PERSONAL',
              members: {
                create: [
                  { userId, role: 'MEMBER' },
                  { userId: otherUserId, role: 'MEMBER' }
                ]
              }
            }
          });
        }

        effectiveConversationId = existingConv.id;
        member = await this.prisma.conversationMember.findFirst({
          where: { conversationId: effectiveConversationId, userId, leftAt: null }
        });
      }
    }

    if (!member) {
      throw new ForbiddenException('Not an active member of this conversation');
    }

    const activeDeviceId = await this.getValidDeviceId(userId, deviceId);

    // 2. Idempotency check on (sender_device_id, client_message_id)
    const existing = await this.prisma.message.findUnique({
      where: {
        senderDeviceId_clientMessageId: {
          senderDeviceId: activeDeviceId,
          clientMessageId: dto.clientMessageId
        }
      }
    });
    if (existing) {
      return existing;
    }

    // 3. Single PostgreSQL transaction writes: message + conversation event + outbox event
    const createdMessage = await this.prisma.$transaction(async (tx) => {
      let expiresAt: Date | null = null;
      if (dto.expiresInSeconds && dto.expiresInSeconds > 0) {
        expiresAt = new Date(Date.now() + dto.expiresInSeconds * 1000);
      }

      const message = await tx.message.create({
        data: {
          conversationId: effectiveConversationId,
          senderUserId: userId,
          senderDeviceId: activeDeviceId,
          clientMessageId: dto.clientMessageId,
          ciphertext: dto.ciphertext,
          nonce: dto.nonce,
          messageType: dto.messageType || 'TEXT',
          state: 'SENT',
          expiresAt
        }
      });

      const conversationEvent = await tx.conversationEvent.create({
        data: {
          conversationId: effectiveConversationId,
          eventType: 'MESSAGE_CREATED',
          payload: JSON.stringify({
            messageId: message.id,
            sequence: message.sequence,
            senderUserId: userId,
            senderDeviceId: activeDeviceId,
            messageType: message.messageType,
            createdAt: message.createdAt
          })
        }
      });

      await tx.outboxEvent.create({
        data: {
          aggregateType: 'CONVERSATION',
          aggregateId: effectiveConversationId,
          eventType: 'MESSAGE_SENT',
          payload: JSON.stringify({
            conversationId: effectiveConversationId,
            messageId: message.id,
            sequence: message.sequence,
            senderUserId: userId,
            senderDeviceId: activeDeviceId,
            ciphertext: message.ciphertext,
            nonce: message.nonce,
            messageType: message.messageType,
            eventId: conversationEvent.id
          }),
          status: 'PENDING'
        }
      });

      return message;
    });

    // Asynchronously dispatch high-priority push notification (killed-state wakeups)
    this.dispatchPushNotifications(userId, effectiveConversationId, createdMessage).catch((err) => {
      this.logger.warn(`Failed to dispatch push notification: ${err.message}`);
    });

    return createdMessage;
  }

  private async dispatchPushNotifications(
    senderUserId: string,
    conversationId: string,
    message: any
  ) {
    try {
      const sender = await this.prisma.user.findUnique({
        where: { id: senderUserId },
        select: { username: true }
      });
      const senderName = sender?.username || 'Seseorang';

      const recipientMembers = await this.prisma.conversationMember.findMany({
        where: {
          conversationId,
          userId: { not: senderUserId },
          leftAt: null
        },
        include: {
          user: {
            include: {
              devices: {
                where: { status: 'ACTIVE' },
                include: {
                  pushDevices: true
                }
              }
            }
          }
        }
      });

      const messagePreview = message.messageType === 'TEXT'
        ? 'Pesan baru'
        : `Mengirim ${message.messageType.toLowerCase()}`;

      for (const member of recipientMembers) {
        if (this.redisService) {
          try {
            await this.redisService.getClient().publish(
              `user:${member.userId}`,
              JSON.stringify({
                type: 'NEW_MESSAGE',
                conversationId,
                senderName,
                preview: messagePreview,
                messageId: message.id
              })
            );
          } catch (_) {}
        }

        for (const device of member.user.devices) {
          const tokens: string[] = [];
          if (device.pushDevices && device.pushDevices.length > 0) {
            for (const pd of device.pushDevices) {
              if (pd.clientToken) tokens.push(pd.clientToken);
            }
          }
          if (device.pushToken && !tokens.includes(device.pushToken)) {
            tokens.push(device.pushToken);
          }

          if (tokens.length === 0) {
            // Fallback to conversation wakeup via default Gotify channel
            await this.gotifyService.sendPushNotification({
              title: senderName,
              message: messagePreview,
              conversationId,
              priority: 6
            });
          } else {
            for (const token of tokens) {
              await this.gotifyService.sendPushNotification({
                targetToken: token,
                title: senderName,
                message: messagePreview,
                conversationId,
                priority: 6
              });
            }
          }
        }
      }
    } catch (err: any) {
      this.logger.warn(`dispatchPushNotifications error: ${err.message}`);
    }
  }

  async deleteForEveryone(userId: string, messageId: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
      include: { conversation: { include: { members: true } } }
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    const currentMember = message.conversation.members.find((m) => m.userId === userId);
    const isSender = message.senderUserId === userId;
    const isOwnerOrAdmin =
      currentMember && (currentMember.role === 'OWNER' || currentMember.role === 'ADMIN');

    if (!isSender && !isOwnerOrAdmin) {
      throw new ForbiddenException('Not authorized to delete this message');
    }

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.message.update({
        where: { id: messageId },
        data: {
          state: 'DELETED',
          ciphertext: '',
          deletedAt: new Date()
        }
      });

      const convEvent = await tx.conversationEvent.create({
        data: {
          conversationId: message.conversationId,
          eventType: 'MESSAGE_DELETED',
          payload: JSON.stringify({ messageId, deletedBy: userId })
        }
      });

      await tx.outboxEvent.create({
        data: {
          aggregateType: 'CONVERSATION',
          aggregateId: message.conversationId,
          eventType: 'MESSAGE_DELETED',
          payload: JSON.stringify({
            conversationId: message.conversationId,
            messageId,
            deletedBy: userId,
            eventId: convEvent.id
          }),
          status: 'PENDING'
        }
      });

      return updated;
    });
  }

  async editMessage(userId: string, messageId: string, ciphertext: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId }
    });

    if (!message) {
      throw new NotFoundException('Message not found');
    }

    if (message.senderUserId !== userId) {
      throw new ForbiddenException('Only the sender can edit this message');
    }

    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.message.update({
        where: { id: messageId },
        data: {
          ciphertext
        }
      });

      const convEvent = await tx.conversationEvent.create({
        data: {
          conversationId: message.conversationId,
          eventType: 'MESSAGE_EDITED',
          payload: JSON.stringify({ messageId, editedBy: userId, ciphertext })
        }
      });

      await tx.outboxEvent.create({
        data: {
          aggregateType: 'CONVERSATION',
          aggregateId: message.conversationId,
          eventType: 'MESSAGE_EDITED',
          payload: JSON.stringify({
            conversationId: message.conversationId,
            messageId,
            ciphertext,
            editedBy: userId,
            eventId: convEvent.id
          }),
          status: 'PENDING'
        }
      });

      return updated;
    });
  }

  async acknowledgeDelivery(deviceId: string, messageId: string) {
    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
      select: { id: true }
    });
    if (!msg) {
      return null;
    }

    return this.prisma.messageDelivery.upsert({
      where: {
        messageId_deviceId: { messageId, deviceId }
      },
      update: {
        status: 'DELIVERED',
        deliveredAt: new Date()
      },
      create: {
        messageId,
        deviceId,
        status: 'DELIVERED',
        deliveredAt: new Date()
      }
    });
  }

  async markRead(deviceId: string, messageId: string) {
    const msg = await this.prisma.message.findUnique({
      where: { id: messageId },
      select: { id: true }
    });
    if (!msg) {
      return null;
    }

    return this.prisma.messageDelivery.upsert({
      where: {
        messageId_deviceId: { messageId, deviceId }
      },
      update: {
        status: 'READ',
        readAt: new Date()
      },
      create: {
        messageId,
        deviceId,
        status: 'READ',
        deliveredAt: new Date(),
        readAt: new Date()
      }
    });
  }

  async addReaction(userId: string, messageId: string, emoji: string) {
    const message = await this.prisma.message.findUnique({
      where: { id: messageId }
    });
    if (!message) {
      throw new NotFoundException('Message not found');
    }

    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId: message.conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Not a member of this conversation');
    }

    return this.prisma.messageReaction.upsert({
      where: {
        messageId_userId_emoji: {
          messageId,
          userId,
          emoji
        }
      },
      update: {},
      create: {
        messageId,
        userId,
        emoji
      }
    });
  }

  async removeReaction(userId: string, messageId: string, emoji: string) {
    return this.prisma.messageReaction.deleteMany({
      where: {
        messageId,
        userId,
        emoji
      }
    });
  }
}

