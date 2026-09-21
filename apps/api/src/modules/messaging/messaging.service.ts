import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { SendMessageDto } from './dto/message.dto';

@Injectable()
export class MessagingService {
  private readonly logger = new Logger(MessagingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gotifyService: GotifyService
  ) {}

  async sendMessage(
    userId: string,
    deviceId: string,
    conversationId: string,
    dto: SendMessageDto
  ) {
    // 1. Verify user membership
    const member = await this.prisma.conversationMember.findFirst({
      where: { conversationId, userId, leftAt: null }
    });
    if (!member) {
      throw new ForbiddenException('Not an active member of this conversation');
    }

    // 2. Idempotency check on (sender_device_id, client_message_id)
    const existing = await this.prisma.message.findUnique({
      where: {
        senderDeviceId_clientMessageId: {
          senderDeviceId: deviceId,
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
          conversationId,
          senderUserId: userId,
          senderDeviceId: deviceId,
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
          conversationId,
          eventType: 'MESSAGE_CREATED',
          payload: JSON.stringify({
            messageId: message.id,
            sequence: message.sequence,
            senderUserId: userId,
            senderDeviceId: deviceId,
            messageType: message.messageType,
            createdAt: message.createdAt
          })
        }
      });

      await tx.outboxEvent.create({
        data: {
          aggregateType: 'CONVERSATION',
          aggregateId: conversationId,
          eventType: 'MESSAGE_SENT',
          payload: JSON.stringify({
            conversationId,
            messageId: message.id,
            sequence: message.sequence,
            senderUserId: userId,
            senderDeviceId: deviceId,
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
    this.dispatchPushNotifications(userId, conversationId, createdMessage).catch((err) => {
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
        ? 'Pesan baru terenkripsi'
        : `Mengirim ${message.messageType.toLowerCase()}`;

      for (const member of recipientMembers) {
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

