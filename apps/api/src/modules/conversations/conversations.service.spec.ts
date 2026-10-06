import { Test, TestingModule } from '@nestjs/testing';
import { ConversationsService } from './conversations.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { ConversationType, ConversationRole } from '@secure-messenger/shared-types';
import { BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';

describe('ConversationsService', () => {
  let service: ConversationsService;
  let prisma: any;
  let redis: any;

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
      },
      conversation: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        update: jest.fn(),
      },
      conversationMember: {
        create: jest.fn(),
        findFirst: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      conversationEvent: {
        create: jest.fn(),
      },
      $transaction: jest.fn(async (cb) => {
        if (typeof cb === 'function') {
          return cb(prisma);
        }
        return Promise.all(cb);
      }),
    };

    redis = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue('OK'),
      getClient: jest.fn().mockReturnValue({
        publish: jest.fn().mockResolvedValue(1),
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ConversationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: redis },
      ],
    }).compile();

    service = module.get<ConversationsService>(ConversationsService);
  });

  describe('createConversation (GROUP)', () => {
    it('should throw BadRequestException if participantUserIds is empty', async () => {
      await expect(
        service.createConversation('user-creator', {
          type: ConversationType.GROUP,
          title: 'Test Group',
          participantUserIds: [],
        })
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw NotFoundException if currentUser does not exist', async () => {
      prisma.user.findUnique.mockResolvedValueOnce(null);

      await expect(
        service.createConversation('user-creator', {
          type: ConversationType.GROUP,
          title: 'Test Group',
          participantUserIds: ['user-1'],
        })
      ).rejects.toThrow(NotFoundException);
    });

    it('should successfully create a group conversation with creator as OWNER and participants as MEMBER', async () => {
      const creatorId = '11111111-1111-1111-1111-111111111111';
      const member1Id = '22222222-2222-2222-2222-222222222222';
      const member2Id = '33333333-3333-3333-3333-333333333333';

      prisma.user.findUnique.mockImplementation(({ where }: any) => {
        if (where.id === creatorId) {
          return Promise.resolve({ id: creatorId, username: 'Creator' });
        }
        if (where.id === member1Id) {
          return Promise.resolve({ id: member1Id, username: 'Member1' });
        }
        if (where.id === member2Id) {
          return Promise.resolve({ id: member2Id, username: 'Member2' });
        }
        return Promise.resolve(null);
      });

      // 2. Transaction mocks
      const createdConv = { id: 'conv-group-1', type: ConversationType.GROUP, title: 'My Awesome Group' };
      prisma.conversation.create.mockResolvedValue(createdConv);
      prisma.conversationMember.create.mockResolvedValue({});
      prisma.conversationEvent.create.mockResolvedValue({});
      prisma.conversation.findUnique.mockResolvedValue({
        ...createdConv,
        members: [
          { userId: creatorId, role: ConversationRole.OWNER, user: { id: creatorId, username: 'Creator' } },
          { userId: member1Id, role: ConversationRole.MEMBER, user: { id: member1Id, username: 'Member1' } },
          { userId: member2Id, role: ConversationRole.MEMBER, user: { id: member2Id, username: 'Member2' } },
        ],
      });

      const result = await service.createConversation(creatorId, {
        type: ConversationType.GROUP,
        title: 'My Awesome Group',
        description: 'Test group description',
        participantUserIds: [member1Id, member2Id],
      });

      expect(prisma.conversation.create).toHaveBeenCalledWith({
        data: {
          type: ConversationType.GROUP,
          title: 'My Awesome Group',
          description: 'Test group description',
          avatarUrl: null,
        },
      });

      // Creator added as OWNER
      expect(prisma.conversationMember.create).toHaveBeenCalledWith({
        data: {
          conversationId: 'conv-group-1',
          userId: creatorId,
          role: ConversationRole.OWNER,
        },
      });

      // Member 1 added as MEMBER
      expect(prisma.conversationMember.create).toHaveBeenCalledWith({
        data: {
          conversationId: 'conv-group-1',
          userId: member1Id,
          role: ConversationRole.MEMBER,
        },
      });

      // Member 2 added as MEMBER
      expect(prisma.conversationMember.create).toHaveBeenCalledWith({
        data: {
          conversationId: 'conv-group-1',
          userId: member2Id,
          role: ConversationRole.MEMBER,
        },
      });

      // Description saved to Redis
      expect(redis.set).toHaveBeenCalledWith('conversation:conv-group-1:description', 'Test group description');

      // Redis event published to members
      const publisher = redis.getClient();
      expect(publisher.publish).toHaveBeenCalledWith(
        `user:${member1Id}`,
        expect.stringContaining('NEW_CONVERSATION')
      );
      expect(publisher.publish).toHaveBeenCalledWith(
        `user:${member2Id}`,
        expect.stringContaining('NEW_CONVERSATION')
      );

      expect(result.id).toBe('conv-group-1');
      expect((result as any).description).toBe('Test group description');
    });

    it('should throw BadRequestException if all selected participants are invalid or self', async () => {
      prisma.user.findUnique.mockImplementation(({ where }: any) => {
        if (where.id === 'user-creator') {
          return Promise.resolve({ id: 'user-creator', username: 'Creator' });
        }
        return Promise.resolve(null);
      });
      prisma.user.findFirst.mockResolvedValue(null);

      await expect(
        service.createConversation('user-creator', {
          type: ConversationType.GROUP,
          title: 'Empty Group',
          participantUserIds: ['non-existent-user'],
        })
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('getConversation', () => {
    it('should throw ForbiddenException if user is not a member', async () => {
      prisma.conversationMember.findFirst.mockResolvedValue(null);

      await expect(
        service.getConversation('intruder', 'conv-1')
      ).rejects.toThrow(ForbiddenException);
    });

    it('should return enriched conversation with description and permissions', async () => {
      prisma.conversationMember.findFirst.mockResolvedValue({ id: 'mem-1', userId: 'user-1' });
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        title: 'Group 1',
        members: [{ userId: 'user-1', user: { id: 'user-1', username: 'Alice' } }],
      });
      redis.get.mockImplementation((key: string) => {
        if (key === 'conversation:conv-1:description') return Promise.resolve('Group Desc');
        if (key === 'conversation:conv-1:permissions') return Promise.resolve(JSON.stringify({ canSendMessages: true }));
        return Promise.resolve(null);
      });

      const res = await service.getConversation('user-1', 'conv-1');
      expect(res).toBeDefined();
      expect((res as any)?.description).toBe('Group Desc');
      expect((res as any)?.permissions).toEqual({ canSendMessages: true });
    });
  });
});
