import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ForbiddenException } from '@nestjs/common';

describe('AdminService Controlled Access', () => {
  let service: AdminService;
  let prisma: any;

  beforeEach(async () => {
    prisma = {
      conversation: { findUnique: jest.fn() },
      conversationAccessGrant: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn()
      },
      conversationAccessApproval: { create: jest.fn() },
      message: { findMany: jest.fn() },
      $transaction: jest.fn((cb) => cb(prisma))
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        { provide: PrismaService, useValue: prisma }
      ]
    }).compile();

    service = module.get<AdminService>(AdminService);
  });

  it('should prevent requester from approving their own grant (dual-approval)', async () => {
    prisma.conversationAccessGrant.findUnique.mockResolvedValue({
      id: 'grant-1',
      requestedById: 'admin-alice',
      status: 'PENDING'
    });

    await expect(
      service.approveConversationAccess('admin-alice', 'grant-1')
    ).rejects.toThrow(ForbiddenException);
  });

  it('should approve grant when approver is different from requester', async () => {
    prisma.conversationAccessGrant.findUnique.mockResolvedValue({
      id: 'grant-1',
      requestedById: 'admin-alice',
      status: 'PENDING'
    });
    prisma.conversationAccessGrant.update.mockResolvedValue({
      id: 'grant-1',
      status: 'APPROVED'
    });

    const result = await service.approveConversationAccess('admin-bob', 'grant-1');
    expect(result.status).toBe('APPROVED');
    expect(prisma.conversationAccessApproval.create).toHaveBeenCalledWith({
      data: {
        grantId: 'grant-1',
        approvedById: 'admin-bob'
      }
    });
  });

  it('should forbid reading messages without active approved grant', async () => {
    prisma.conversationAccessGrant.findFirst.mockResolvedValue(null);

    await expect(
      service.readAuthorizedConversationMessages('admin-alice', 'conv-123')
    ).rejects.toThrow(ForbiddenException);
  });
});
