import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';

describe('UsersService', () => {
  let service: UsersService;
  let prisma: any;
  let redis: any;

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        count: jest.fn(),
        update: jest.fn()
      }
    };

    redis = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue('OK'),
      del: jest.fn().mockResolvedValue(1)
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: redis }
      ]
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should return user profile when user exists', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u-1',
      username: 'satria',
      email: 'satria@laju.id',
      phoneNumber: '+628123456789',
      status: 'ACTIVE',
      twoFactorEnabled: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      devices: []
    });

    const result = await service.getProfile('u-1');
    expect(result.id).toBe('u-1');
    expect(result.username).toBe('satria');
  });

  it('should throw NotFoundException when user does not exist', async () => {
    prisma.user.findUnique.mockResolvedValue(null);

    await expect(service.getProfile('non-existent')).rejects.toThrow(NotFoundException);
  });

  it('should throw ConflictException if updated username already taken', async () => {
    prisma.user.findUnique
      .mockResolvedValueOnce({ id: 'u-1', username: 'old_name' }) // find current user
      .mockResolvedValueOnce({ id: 'u-2', username: 'taken_name' }); // check username conflict

    await expect(
      service.updateProfile('u-1', { username: 'taken_name' })
    ).rejects.toThrow(ConflictException);
  });

  it('should search active users excluding requesting user', async () => {
    prisma.user.findMany.mockResolvedValue([
      { id: 'u-2', username: 'dimas', email: 'dimas@laju.id', status: 'ACTIVE' }
    ]);
    prisma.user.count.mockResolvedValue(1);

    const result = await service.searchUsers('u-1', 'dimas');
    expect(result.users).toHaveLength(1);
    expect(result.users[0].username).toBe('dimas');
    expect(prisma.user.findMany).toHaveBeenCalled();
  });
});
