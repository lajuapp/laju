import { Test, TestingModule } from '@nestjs/testing';
import { MessagingService } from './messaging.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ForbiddenException } from '@nestjs/common';
import { MessageType } from '@secure-messenger/shared-types';

describe('MessagingService', () => {
  let service: MessagingService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      conversationMember: {
        findFirst: jest.fn()
      },
      message: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn()
      },
      conversationEvent: {
        create: jest.fn()
      },
      device: {
        findFirst: jest.fn().mockResolvedValue({ id: 'dev1', userId: 'user1', status: 'ACTIVE' }),
        create: jest.fn().mockResolvedValue({ id: 'dev1', userId: 'user1', status: 'ACTIVE' }),
        update: jest.fn().mockResolvedValue({ id: 'dev1', userId: 'user1', status: 'ACTIVE' })
      },
      outboxEvent: {
        create: jest.fn()
      },
      $transaction: jest.fn((cb) => cb(prisma))
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MessagingService,
        { provide: PrismaService, useValue: prisma }
      ]
    }).compile();

    service = module.get<MessagingService>(MessagingService);
  });

  it('should reject if user is not a conversation member', async () => {
    prisma.conversationMember.findFirst.mockResolvedValue(null);

    await expect(
      service.sendMessage('user1', 'dev1', 'conv1', {
        clientMessageId: 'msg-1',
        ciphertext: 'enc-data',
        nonce: 'nonce-123'
      })
    ).rejects.toThrow(ForbiddenException);
  });

  it('should return existing message if clientMessageId already exists (idempotency)', async () => {
    prisma.conversationMember.findFirst.mockResolvedValue({ id: 'mem1', userId: 'user1' });
    const existingMsg = {
      id: 'existing-id',
      clientMessageId: 'msg-1',
      senderDeviceId: 'dev1',
      ciphertext: 'enc-data'
    };
    prisma.message.findUnique.mockResolvedValue(existingMsg);

    const result = await service.sendMessage('user1', 'dev1', 'conv1', {
      clientMessageId: 'msg-1',
      ciphertext: 'enc-data',
      nonce: 'nonce-123'
    });

    expect(result).toBe(existingMsg);
    expect(prisma.message.create).not.toHaveBeenCalled();
    expect(prisma.outboxEvent.create).not.toHaveBeenCalled();
  });

  it('should atomically create message, conversation_event, and outbox_event in transaction', async () => {
    prisma.conversationMember.findFirst.mockResolvedValue({ id: 'mem1', userId: 'user1' });
    prisma.message.findUnique.mockResolvedValue(null);

    const createdMsg = {
      id: 'msg-uuid',
      conversationId: 'conv1',
      sequence: 1,
      ciphertext: 'enc-data',
      nonce: 'nonce-123',
      messageType: MessageType.TEXT,
      createdAt: new Date()
    };
    prisma.message.create.mockResolvedValue(createdMsg);

    const createdConvEvent = { id: 'evt-uuid' };
    prisma.conversationEvent.create.mockResolvedValue(createdConvEvent);

    const createdOutboxEvent = { id: 'outbox-uuid' };
    prisma.outboxEvent.create.mockResolvedValue(createdOutboxEvent);

    const result = await service.sendMessage('user1', 'dev1', 'conv1', {
      clientMessageId: 'msg-unique-123',
      ciphertext: 'enc-data',
      nonce: 'nonce-123'
    });

    expect(result).toBe(createdMsg);
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(prisma.message.create).toHaveBeenCalled();
    expect(prisma.conversationEvent.create).toHaveBeenCalled();
    expect(prisma.outboxEvent.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        aggregateType: 'CONVERSATION',
        aggregateId: 'conv1',
        eventType: 'MESSAGE_SENT',
        status: 'PENDING'
      })
    });
  });
});
