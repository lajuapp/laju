import { Test, TestingModule } from '@nestjs/testing';
import { DevicesService } from './devices.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { AuthenticationService } from '../authentication/authentication.service';
import { UnauthorizedException, NotFoundException } from '@nestjs/common';
import * as crypto from 'crypto';

describe('DevicesService', () => {
  let service: DevicesService;
  let prisma: any;
  let authService: any;
  let redisService: any;

  beforeEach(async () => {
    prisma = {
      device: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        findMany: jest.fn()
      },
      deviceKey: {
        create: jest.fn()
      },
      preKey: {
        upsert: jest.fn()
      },
      session: {
        deleteMany: jest.fn()
      },
      securityEvent: {
        create: jest.fn()
      },
      $transaction: jest.fn((cb) => (typeof cb === 'function' ? cb(prisma) : Promise.all(cb)))
    };

    authService = {
      generateTokens: jest.fn().mockResolvedValue({
        accessToken: 'mock_jwt_token',
        tokenType: 'Bearer',
        expiresIn: '7d'
      })
    };

    redisService = {
      getClient: jest.fn().mockReturnValue(null) // test fallback cache
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DevicesService,
        { provide: PrismaService, useValue: prisma },
        { provide: RedisService, useValue: redisService },
        { provide: AuthenticationService, useValue: authService }
      ]
    }).compile();

    service = module.get<DevicesService>(DevicesService);
  });

  describe('createChallenge', () => {
    it('should generate a 32-byte base64 nonce with 180s expiration', async () => {
      const result = await service.createChallenge({ deviceUuid: 'dev-1' });
      expect(result.challenge).toBeDefined();
      expect(result.expiresInSeconds).toBe(180);
      expect(result.expiresAt).toBeInstanceOf(Date);
    });
  });

  describe('verifyChallenge', () => {
    it('should verify signature successfully and return tokens', async () => {
      // 1. Generate challenge
      const challengeRes = await service.createChallenge({ deviceUuid: 'dev-1' });
      const challenge = challengeRes.challenge;

      // 2. Mock device & user
      prisma.device.findUnique.mockResolvedValue({
        id: 'd-1',
        deviceUuid: 'dev-1',
        devicePublicKey: 'mock_pub_key',
        status: 'ACTIVE',
        userId: 'u-1',
        user: { id: 'u-1', username: 'satria', status: 'ACTIVE' },
        deviceKeys: []
      });

      // 3. Verify with real HMAC signature
      const sig = crypto.createHmac('sha256', 'mock_pub_key').update(challenge).digest('base64');
      const verifyRes = await service.verifyChallenge({
        deviceUuid: 'dev-1',
        challenge,
        signature: sig
      });

      expect(verifyRes.accessToken).toBe('mock_jwt_token');
      expect(verifyRes.device.deviceUuid).toBe('dev-1');
      expect(prisma.device.update).toHaveBeenCalled();
      expect(prisma.securityEvent.create).toHaveBeenCalled();
    });

    it('should fail when challenge nonce is unknown or expired', async () => {
      await expect(
        service.verifyChallenge({
          deviceUuid: 'dev-1',
          challenge: 'non_existent_challenge',
          signature: 'sig'
        })
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('revokeDevice', () => {
    it('should update device status to REVOKED and delete active sessions', async () => {
      prisma.device.findUnique.mockResolvedValue({
        id: 'd-1',
        userId: 'u-1',
        deviceUuid: 'dev-1',
        status: 'ACTIVE'
      });

      const res = await service.revokeDevice('u-1', 'd-1');
      expect(res.success).toBe(true);
      expect(prisma.device.update).toHaveBeenCalled();
      expect(prisma.session.deleteMany).toHaveBeenCalled();
      expect(prisma.securityEvent.create).toHaveBeenCalled();
    });
  });
});
