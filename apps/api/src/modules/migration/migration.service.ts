import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
  Logger
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { AuthenticationService } from '../authentication/authentication.service';
import {
  StartMigrationDto,
  JoinMigrationDto,
  VerifySasDto,
  CommitMigrationDto
} from './dto/migration.dto';

@Injectable()
export class MigrationService {
  private readonly logger = new Logger(MigrationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly authService: AuthenticationService
  ) {}

  /**
   * Phase 1: Source initiates migration and generates dynamic QR material.
   */
  async startMigration(userId: string, sourceDeviceId: string, dto: StartMigrationDto) {
    const sourceDevice = await this.prisma.device.findUnique({
      where: { id: sourceDeviceId }
    });

    if (!sourceDevice || sourceDevice.userId !== userId) {
      throw new ForbiddenException('Source device not found or unauthorized');
    }

    if (sourceDevice.status !== 'ACTIVE') {
      throw new BadRequestException(`Source device is not active (status: ${sourceDevice.status})`);
    }

    // Cancel any previous pending migrations for this source device
    await this.prisma.deviceMigration.updateMany({
      where: {
        sourceDeviceId,
        status: { in: ['PREPARED', 'TRANSFERRING', 'VERIFYING', 'COMMITTING'] }
      },
      data: { status: 'CANCELLED' }
    });

    const challenge = crypto.randomBytes(32).toString('base64');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes TTL

    const migration = await this.prisma.deviceMigration.create({
      data: {
        identityId: userId,
        sourceDeviceId,
        status: 'PREPARED',
        challenge,
        sourceEphemeralKey: dto.sourceEphemeralKey,
        expiresAt
      }
    });

    await this.prisma.securityEvent.create({
      data: {
        userId,
        deviceId: sourceDeviceId,
        eventType: 'MIGRATION_STARTED',
        severity: 'MEDIUM',
        details: JSON.stringify({ migrationId: migration.id, sourceDeviceId })
      }
    });

    return {
      protocol: 'LAJU-MIGRATION',
      version: 1,
      migrationId: migration.id,
      sourceDeviceId: migration.sourceDeviceId,
      ephemeralPublicKey: migration.sourceEphemeralKey,
      challenge: migration.challenge,
      expiresAt: migration.expiresAt.toISOString()
    };
  }

  /**
   * Phase 2: Target scans QR, connects, and establishes mutual SAS (Short Authentication String).
   */
  async joinMigration(migrationId: string, dto: JoinMigrationDto) {
    const migration = await this.prisma.deviceMigration.findUnique({
      where: { id: migrationId },
      include: { sourceDevice: true }
    });

    if (!migration) {
      throw new NotFoundException('Migration session not found');
    }

    if (migration.status !== 'PREPARED') {
      throw new BadRequestException(`Migration cannot be joined in state: ${migration.status}`);
    }

    if (new Date() > migration.expiresAt) {
      await this.prisma.deviceMigration.update({
        where: { id: migrationId },
        data: { status: 'EXPIRED' }
      });
      throw new BadRequestException('Migration session has expired');
    }

    // Register or prepare target device in PENDING state
    let targetDevice = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.targetDeviceUuid }
    });

    if (!targetDevice) {
      targetDevice = await this.prisma.device.create({
        data: {
          userId: migration.identityId,
          deviceUuid: dto.targetDeviceUuid,
          name: dto.deviceName || 'New Device',
          devicePublicKey: dto.targetPublicKey,
          platform: dto.platform || 'android',
          attestationData: dto.attestationData,
          status: 'PENDING',
          lastSeenAt: new Date()
        }
      });
    } else {
      targetDevice = await this.prisma.device.update({
        where: { id: targetDevice.id },
        data: {
          userId: migration.identityId,
          devicePublicKey: dto.targetPublicKey,
          name: dto.deviceName || targetDevice.name,
          platform: dto.platform || targetDevice.platform,
          attestationData: dto.attestationData || targetDevice.attestationData,
          status: 'PENDING',
          lastSeenAt: new Date()
        }
      });
    }

    // Also register device key for target
    await this.prisma.deviceKey.create({
      data: {
        deviceId: targetDevice.id,
        identityKey: dto.targetPublicKey
      }
    });

    // Derive deterministic 6-digit SAS code via HMAC-SHA256:
    // SAS = HMAC-SHA256(challenge, sourceEphemeralKey || targetEphemeralKey) mod 1,000,000
    const hmac = crypto.createHmac('sha256', migration.challenge);
    hmac.update(migration.sourceEphemeralKey + dto.targetEphemeralKey);
    const digest = hmac.digest();
    const sasNum = (Math.abs(digest.readInt32BE(0)) % 900000) + 100000;
    const sasCode = `${Math.floor(sasNum / 1000)} ${sasNum % 1000}`;

    const updated = await this.prisma.deviceMigration.update({
      where: { id: migrationId },
      data: {
        targetDeviceId: targetDevice.id,
        targetEphemeralKey: dto.targetEphemeralKey,
        sasCode,
        status: 'VERIFYING'
      }
    });

    await this.prisma.securityEvent.create({
      data: {
        userId: migration.identityId,
        deviceId: targetDevice.id,
        eventType: 'MIGRATION_JOINED',
        severity: 'MEDIUM',
        details: JSON.stringify({
          migrationId,
          targetDeviceId: targetDevice.id,
          targetDeviceUuid: targetDevice.deviceUuid
        })
      }
    });

    return {
      migrationId: updated.id,
      status: updated.status,
      sasCode,
      expiresAt: updated.expiresAt.toISOString()
    };
  }

  /**
   * Phase 3: Out-of-band mutual verification of the SAS string.
   */
  async verifyMigration(migrationId: string, dto: VerifySasDto) {
    const migration = await this.prisma.deviceMigration.findUnique({
      where: { id: migrationId }
    });

    if (!migration) {
      throw new NotFoundException('Migration session not found');
    }

    if (migration.status !== 'VERIFYING' && migration.status !== 'TRANSFERRING') {
      throw new BadRequestException(`Migration not in verifiable state (current: ${migration.status})`);
    }

    if (new Date() > migration.expiresAt) {
      await this.prisma.deviceMigration.update({
        where: { id: migrationId },
        data: { status: 'EXPIRED' }
      });
      throw new BadRequestException('Migration session has expired');
    }

    const cleanInput = dto.sasCode.replace(/\s+/g, '');
    const cleanStored = (migration.sasCode || '').replace(/\s+/g, '');

    if (cleanInput !== cleanStored) {
      await this.prisma.deviceMigration.update({
        where: { id: migrationId },
        data: { status: 'FAILED', failureReason: 'SAS mismatch' }
      });
      throw new BadRequestException('SAS mutual verification code does not match');
    }

    const updated = await this.prisma.deviceMigration.update({
      where: { id: migrationId },
      data: { status: 'COMMITTING' }
    });

    await this.prisma.securityEvent.create({
      data: {
        userId: migration.identityId,
        deviceId: migration.targetDeviceId,
        eventType: 'MIGRATION_VERIFIED',
        severity: 'LOW',
        details: JSON.stringify({ migrationId })
      }
    });

    return {
      success: true,
      status: updated.status
    };
  }

  /**
   * Phase 4: Two-Phase Commit (2PC) Atomic Swap.
   * New device is marked ACTIVE.
   * Old device is marked REVOKED and its sessions deleted immediately.
   */
  async commitMigration(migrationId: string, dto?: CommitMigrationDto) {
    const migration = await this.prisma.deviceMigration.findUnique({
      where: { id: migrationId }
    });

    if (!migration) {
      throw new NotFoundException('Migration session not found');
    }

    if (
      migration.status !== 'COMMITTING' &&
      migration.status !== 'VERIFYING' &&
      migration.status !== 'TRANSFERRING'
    ) {
      throw new BadRequestException(`Migration cannot be committed in state: ${migration.status}`);
    }

    if (!migration.targetDeviceId) {
      throw new BadRequestException('No target device attached to migration');
    }

    if (new Date() > migration.expiresAt) {
      await this.prisma.deviceMigration.update({
        where: { id: migrationId },
        data: { status: 'EXPIRED' }
      });
      throw new BadRequestException('Migration session has expired');
    }

    const now = new Date();

    // Execute atomic 2PC Transaction
    await this.prisma.$transaction(async (tx) => {
      // 1. Target device becomes ACTIVE
      await tx.device.update({
        where: { id: migration.targetDeviceId! },
        data: {
          status: 'ACTIVE',
          lastSeenAt: now
        }
      });

      // 2. Source device becomes REVOKED
      await tx.device.update({
        where: { id: migration.sourceDeviceId },
        data: {
          status: 'INACTIVE',
          revokedAt: now
        }
      });

      // 3. Invalidate all active sessions of source device
      await tx.session.deleteMany({
        where: { deviceId: migration.sourceDeviceId }
      });

      // 4. Update migration record to COMMITTED
      await tx.deviceMigration.update({
        where: { id: migrationId },
        data: {
          status: 'COMMITTED',
          committedAt: now
        }
      });

      // 5. Audit logs
      await tx.securityEvent.create({
        data: {
          userId: migration.identityId,
          deviceId: migration.targetDeviceId,
          eventType: 'MIGRATION_COMMITTED',
          severity: 'HIGH',
          details: JSON.stringify({
            migrationId,
            newActiveDeviceId: migration.targetDeviceId,
            revokedDeviceId: migration.sourceDeviceId
          })
        }
      });

      await tx.securityEvent.create({
        data: {
          userId: migration.identityId,
          deviceId: migration.sourceDeviceId,
          eventType: 'DEVICE_REVOKED',
          severity: 'HIGH',
          details: JSON.stringify({
            reason: 'MIGRATED_TO_NEW_DEVICE',
            newDeviceId: migration.targetDeviceId
          })
        }
      });
    });

    // 6. Issue new session token for the new Target Device
    const tokens = await this.authService.generateTokens(
      migration.identityId,
      migration.targetDeviceId
    );

    return {
      success: true,
      status: 'COMMITTED',
      targetDeviceId: migration.targetDeviceId,
      sourceDeviceId: migration.sourceDeviceId,
      committedAt: now,
      ...tokens
    };
  }

  /**
   * Cancel pending migration.
   */
  async cancelMigration(migrationId: string, userId?: string) {
    const migration = await this.prisma.deviceMigration.findUnique({
      where: { id: migrationId }
    });

    if (!migration) {
      throw new NotFoundException('Migration session not found');
    }

    if (userId && migration.identityId !== userId) {
      throw new ForbiddenException('Not authorized to cancel this migration');
    }

    if (migration.status === 'COMMITTED') {
      throw new BadRequestException('Cannot cancel an already committed migration');
    }

    await this.prisma.deviceMigration.update({
      where: { id: migrationId },
      data: { status: 'CANCELLED' }
    });

    await this.prisma.securityEvent.create({
      data: {
        userId: migration.identityId,
        deviceId: migration.sourceDeviceId,
        eventType: 'MIGRATION_CANCELLED',
        severity: 'LOW',
        details: JSON.stringify({ migrationId })
      }
    });

    return { success: true, message: 'Migration session cancelled' };
  }

  /**
   * Poll migration status for source and target synchronization.
   */
  async getMigrationStatus(migrationId: string) {
    const migration = await this.prisma.deviceMigration.findUnique({
      where: { id: migrationId },
      include: {
        targetDevice: {
          select: { id: true, deviceUuid: true, name: true, status: true }
        }
      }
    });

    if (!migration) {
      throw new NotFoundException('Migration session not found');
    }

    if (migration.status !== 'COMMITTED' && migration.status !== 'CANCELLED' && new Date() > migration.expiresAt) {
      await this.prisma.deviceMigration.update({
        where: { id: migrationId },
        data: { status: 'EXPIRED' }
      });
      return {
        migrationId: migration.id,
        status: 'EXPIRED',
        expiresAt: migration.expiresAt
      };
    }

    return {
      migrationId: migration.id,
      status: migration.status,
      sasCode: migration.sasCode,
      targetDevice: migration.targetDevice,
      expiresAt: migration.expiresAt,
      committedAt: migration.committedAt
    };
  }
}
