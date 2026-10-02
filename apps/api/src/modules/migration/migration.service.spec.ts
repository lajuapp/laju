import { Test, TestingModule } from '@nestjs/testing';
import { MigrationService } from './migration.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AuthenticationService } from '../authentication/authentication.service';
import { BadRequestException } from '@nestjs/common';

describe('MigrationService', () => {
  let service: MigrationService;
  let prisma: any;
  let authService: any;

  beforeEach(async () => {
    prisma = {
      device: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn()
      },
      deviceKey: {
        create: jest.fn()
      },
      deviceMigration: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn()
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
        accessToken: 'mock_target_jwt',
        tokenType: 'Bearer',
        expiresIn: '7d'
      })
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MigrationService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuthenticationService, useValue: authService }
      ]
    }).compile();

    service = module.get<MigrationService>(MigrationService);
  });

  describe('startMigration', () => {
    it('should create PREPARED migration and return QR code payload', async () => {
      prisma.device.findUnique.mockResolvedValue({
        id: 'dev-old',
        userId: 'u-1',
        status: 'ACTIVE'
      });

      prisma.deviceMigration.create.mockImplementation(({ data }) => ({
        id: 'mig-1',
        sourceDeviceId: data.sourceDeviceId,
        sourceEphemeralKey: data.sourceEphemeralKey,
        challenge: data.challenge,
        status: 'PREPARED',
        expiresAt: data.expiresAt
      }));

      const res = await service.startMigration('u-1', 'dev-old', {
        sourceEphemeralKey: 'pub_eph_old'
      });

      expect(res.protocol).toBe('LAJU-MIGRATION');
      expect(res.migrationId).toBe('mig-1');
      expect(res.sourceDeviceId).toBe('dev-old');
      expect(res.challenge).toBeDefined();
      expect(prisma.deviceMigration.create).toHaveBeenCalled();
    });
  });

  describe('joinMigration', () => {
    it('should register target device in PENDING state and generate 6-digit SAS', async () => {
      prisma.deviceMigration.findUnique.mockResolvedValue({
        id: 'mig-1',
        identityId: 'u-1',
        sourceDeviceId: 'dev-old',
        sourceEphemeralKey: 'pub_eph_old',
        challenge: 'test_challenge_nonce',
        status: 'PREPARED',
        expiresAt: new Date(Date.now() + 100000)
      });

      prisma.device.findUnique.mockResolvedValue(null);
      prisma.device.create.mockResolvedValue({
        id: 'dev-new',
        deviceUuid: 'target-uuid-999',
        status: 'PENDING'
      });

      prisma.deviceMigration.update.mockImplementation(({ data }) => ({
        id: 'mig-1',
        status: data.status,
        sasCode: data.sasCode,
        expiresAt: new Date(Date.now() + 100000)
      }));

      const res = await service.joinMigration('mig-1', {
        targetDeviceUuid: 'target-uuid-999',
        targetPublicKey: 'pub_target',
        targetEphemeralKey: 'pub_eph_new'
      });

      expect(res.status).toBe('VERIFYING');
      expect(res.sasCode).toBeDefined();
      expect(res.sasCode).toMatch(/\d{3} \d{3}/);
      expect(prisma.device.create).toHaveBeenCalled();
    });
  });

  describe('commitMigration', () => {
    it('should atomically activate target device and revoke source device via 2PC', async () => {
      prisma.deviceMigration.findUnique.mockResolvedValue({
        id: 'mig-1',
        identityId: 'u-1',
        sourceDeviceId: 'dev-old',
        targetDeviceId: 'dev-new',
        status: 'COMMITTING',
        expiresAt: new Date(Date.now() + 100000)
      });

      const res = await service.commitMigration('mig-1');

      expect(res.success).toBe(true);
      expect(res.status).toBe('COMMITTED');
      expect(res.accessToken).toBe('mock_target_jwt');
      expect(prisma.device.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'dev-new' },
          data: expect.objectContaining({ status: 'ACTIVE' })
        })
      );
      expect(prisma.device.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'dev-old' },
          data: expect.objectContaining({ status: 'INACTIVE' })
        })
      );
      expect(prisma.session.deleteMany).toHaveBeenCalledWith({
        where: { deviceId: 'dev-old' }
      });
    });
  });
});
