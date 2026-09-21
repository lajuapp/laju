import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException
} from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { SendMessageDto } from './dto/message.dto';

@Injectable()
export class MessagingService {
  constructor(private readonly prisma: PrismaService) {}

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
    return this.prisma.$transaction(async (tx) => {
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
}
