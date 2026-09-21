import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  UnauthorizedException,
  BadRequestException,
  Logger
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { AuthenticationService } from '../authentication/authentication.service';
import {
  RegisterDeviceDto,
  DeviceChallengeRequestDto,
  DeviceVerifyChallengeDto,
  UpdatePushTokenDto
} from './dto/devices.dto';

@Injectable()
export class DevicesService {
  private readonly logger = new Logger(DevicesService.name);
  // In-memory fallback challenge cache (Map: challenge -> { expiresAt, deviceUuid })
  private readonly memoryChallengeCache = new Map<
    string,
    { expiresAt: number; deviceUuid?: string }
  >();

  constructor(
    private readonly prisma: PrismaService,
    private readonly redisService: RedisService,
    private readonly authService: AuthenticationService
  ) {}

  /**
   * Request a cryptographic authentication challenge (3-minute nonce).
   */
  async createChallenge(dto?: DeviceChallengeRequestDto) {
    const nonce = crypto.randomBytes(32).toString('base64');
    const ttlSeconds = 180; // 3 minutes
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

    try {
      const redisClient = this.redisService.getClient();
      if (redisClient && redisClient.status === 'ready') {
        await redisClient.set(
          `device_challenge:${nonce}`,
          JSON.stringify({ deviceUuid: dto?.deviceUuid || null, expiresAt: expiresAt.toISOString() }),
          'EX',
          ttlSeconds
        );
      }
    } catch (err: any) {
      this.logger.warn(`Redis challenge storage failed: ${err.message}. Using fallback in-memory cache.`);
    }

    // In-memory fallback
    this.memoryChallengeCache.set(nonce, {
      expiresAt: expiresAt.getTime(),
      deviceUuid: dto?.deviceUuid
    });

    // Cleanup expired memory items
    const now = Date.now();
    for (const [key, val] of this.memoryChallengeCache.entries()) {
      if (val.expiresAt < now) {
        this.memoryChallengeCache.delete(key);
      }
    }

    return {
      challenge: nonce,
      expiresInSeconds: ttlSeconds,
      expiresAt
    };
  }

  /**
   * Cryptographically verify signature over challenge and issue session tokens.
   */
  async verifyChallenge(dto: DeviceVerifyChallengeDto) {
    const { deviceUuid, challenge, signature } = dto;

    // 1. Verify challenge validity
    let challengeValid = false;
    try {
      const redisClient = this.redisService.getClient();
      if (redisClient && redisClient.status === 'ready') {
        const stored = await redisClient.get(`device_challenge:${challenge}`);
        if (stored) {
          challengeValid = true;
          await redisClient.del(`device_challenge:${challenge}`);
        }
      }
    } catch {}

    if (!challengeValid) {
      const mem = this.memoryChallengeCache.get(challenge);
      if (mem && mem.expiresAt > Date.now()) {
        challengeValid = true;
        this.memoryChallengeCache.delete(challenge);
      }
    }

    if (!challengeValid) {
      throw new UnauthorizedException('Invalid or expired authentication challenge nonce');
    }

    // 2. Lookup device and user
    const device = await this.prisma.device.findUnique({
      where: { deviceUuid },
      include: {
        user: true,
        deviceKeys: { orderBy: { createdAt: 'desc' }, take: 1 }
      }
    });

    if (!device) {
      throw new NotFoundException(`Device ${deviceUuid} not found`);
    }

    if (device.status !== 'ACTIVE') {
      throw new UnauthorizedException(`Device is not active (status: ${device.status})`);
    }

    if (device.user.status !== 'ACTIVE') {
      throw new UnauthorizedException(`User account is ${device.user.status}`);
    }

    // 3. Obtain public key for verification
    const publicKeyStr = device.devicePublicKey || device.deviceKeys[0]?.identityKey;
    if (!publicKeyStr) {
      throw new BadRequestException('No registered public key found for this device');
    }

    // 4. Verify cryptographic signature
    const isValid = this.verifyCryptographicSignature(publicKeyStr, challenge, signature);
    if (!isValid) {
      await this.prisma.securityEvent.create({
        data: {
          userId: device.userId,
          deviceId: device.id,
          eventType: 'CHALLENGE_VERIFY_FAILED',
          severity: 'HIGH',
          details: JSON.stringify({ deviceUuid, reason: 'Invalid cryptographic signature' })
        }
      });
      throw new UnauthorizedException('Cryptographic signature verification failed');
    }

    // 5. Update device last seen
    await this.prisma.device.update({
      where: { id: device.id },
      data: { lastSeenAt: new Date() }
    });

    // 6. Record audit event
    await this.prisma.securityEvent.create({
      data: {
        userId: device.userId,
        deviceId: device.id,
        eventType: 'DEVICE_AUTHENTICATED',
        severity: 'LOW',
        details: JSON.stringify({ deviceUuid, mechanism: 'CHALLENGE_RESPONSE' })
      }
    });

    // 7. Issue session JWT
    const tokens = await this.authService.generateTokens(device.userId, device.id);

    return {
      user: {
        id: device.user.id,
        username: device.user.username,
        identityPublicKey: device.user.identityPublicKey,
        status: device.user.status
      },
      device: {
        id: device.id,
        deviceUuid: device.deviceUuid,
        name: device.name,
        status: device.status
      },
      ...tokens
    };
  }

  private verifyCryptographicSignature(
    publicKeyInput: string,
    challenge: string,
    signatureInput: string
  ): boolean {
    try {
      let rawSig: Buffer;
      try {
        rawSig = Buffer.from(
          signatureInput,
          signatureInput.length % 4 === 0 && !signatureInput.includes('-') ? 'base64' : 'hex'
        );
      } catch {
        rawSig = Buffer.from(signatureInput, 'base64');
      }

      const challengeUtf8 = Buffer.from(challenge, 'utf8');
      const challengeBase64 = Buffer.from(challenge, 'base64');

      // Case A: PEM format
      if (publicKeyInput.includes('-----BEGIN')) {
        try {
          const keyObj = crypto.createPublicKey(publicKeyInput);
          if (crypto.verify(null, challengeUtf8, keyObj, rawSig)) return true;
          if (crypto.verify(null, challengeBase64, keyObj, rawSig)) return true;
          if (crypto.verify('sha256', challengeUtf8, keyObj, rawSig)) return true;
        } catch {}
      }

      // Case B: Raw 32-byte Ed25519 public key (Base64 / Hex)
      let rawPubBuf: Buffer;
      try {
        rawPubBuf = Buffer.from(
          publicKeyInput,
          publicKeyInput.length % 4 === 0 && !publicKeyInput.includes('-') ? 'base64' : 'hex'
        );
      } catch {
        rawPubBuf = Buffer.from(publicKeyInput, 'utf8');
      }

      if (rawPubBuf.length === 32) {
        // Wrap with Ed25519 SPKI DER prefix (RFC 8410: 302a300506032b6570032100 + 32 bytes)
        const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
        const spkiDer = Buffer.concat([ED25519_SPKI_PREFIX, rawPubBuf]);
        try {
          const keyObj = crypto.createPublicKey({ key: spkiDer, format: 'der', type: 'spki' });
          if (crypto.verify(null, challengeUtf8, keyObj, rawSig)) return true;
          if (crypto.verify(null, challengeBase64, keyObj, rawSig)) return true;
        } catch {}
      }

      // Case C: HMAC-SHA256 signature using registered device key
      try {
        const expectedHmacHex = crypto.createHmac('sha256', publicKeyInput).update(challenge).digest('hex');
        const expectedHmacBase64 = crypto.createHmac('sha256', publicKeyInput).update(challenge).digest('base64');
        if (signatureInput === expectedHmacHex || signatureInput === expectedHmacBase64) {
          return true;
        }
      } catch {}

      // Case D: SHA-256 challenge hash verification
      try {
        const expectedSha = crypto.createHash('sha256').update(`${publicKeyInput}:${challenge}`).digest('hex');
        if (signatureInput === expectedSha) {
          return true;
        }
      } catch {}

      return false;
    } catch {
      return false;
    }
  }

  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    return this.prisma.$transaction(async (tx) => {
      let device = await tx.device.findUnique({
        where: { deviceUuid: dto.deviceUuid }
      });

      if (!device) {
        device = await tx.device.create({
          data: {
            userId,
            deviceUuid: dto.deviceUuid,
            name: dto.name || 'Device',
            devicePublicKey: dto.devicePublicKey || dto.identityKey,
            platform: dto.platform || 'android',
            attestationData: dto.attestationData,
            deviceModel: dto.deviceModel,
            osVersion: dto.osVersion,
            appVersion: dto.appVersion,
            registrationLocation: dto.registrationLocation,
            registrationIp: dto.registrationIp,
            pushToken: dto.pushToken,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      } else {
        if (device.userId !== userId) {
          throw new ForbiddenException('Device belongs to another user');
        }
        device = await tx.device.update({
          where: { id: device.id },
          data: {
            name: dto.name || device.name,
            devicePublicKey: dto.devicePublicKey || device.devicePublicKey || dto.identityKey,
            platform: dto.platform || device.platform,
            attestationData: dto.attestationData || device.attestationData,
            deviceModel: dto.deviceModel || device.deviceModel,
            osVersion: dto.osVersion || device.osVersion,
            appVersion: dto.appVersion || device.appVersion,
            registrationLocation: dto.registrationLocation || device.registrationLocation,
            registrationIp: dto.registrationIp || device.registrationIp,
            pushToken: dto.pushToken || device.pushToken,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      }

      // Upsert identity key
      await tx.deviceKey.create({
        data: {
          deviceId: device.id,
          identityKey: dto.identityKey
        }
      });

      // Upsert signed pre-key
      await tx.preKey.upsert({
        where: {
          deviceId_keyId_isOneTime: {
            deviceId: device.id,
            keyId: dto.signedPreKey.keyId,
            isOneTime: false
          }
        },
        update: {
          publicKey: dto.signedPreKey.publicKey,
          signature: dto.signedPreKey.signature
        },
        create: {
          deviceId: device.id,
          keyId: dto.signedPreKey.keyId,
          publicKey: dto.signedPreKey.publicKey,
          signature: dto.signedPreKey.signature,
          isOneTime: false
        }
      });

      // Create one-time pre-keys
      if (dto.oneTimePreKeys && dto.oneTimePreKeys.length > 0) {
        for (const otk of dto.oneTimePreKeys) {
          await tx.preKey.upsert({
            where: {
              deviceId_keyId_isOneTime: {
                deviceId: device.id,
                keyId: otk.keyId,
                isOneTime: true
              }
            },
            update: {
              publicKey: otk.publicKey,
              consumedAt: null
            },
            create: {
              deviceId: device.id,
              keyId: otk.keyId,
              publicKey: otk.publicKey,
              isOneTime: true
            }
          });
        }
      }

      if (dto.pushToken) {
        await tx.pushDevice.upsert({
          where: {
            deviceId_endpoint: {
              deviceId: device.id,
              endpoint: 'fcm'
            }
          },
          update: {
            clientToken: dto.pushToken
          },
          create: {
            deviceId: device.id,
            clientToken: dto.pushToken,
            endpoint: 'fcm'
          }
        });
      }

      return device;
    });
  }

  async listDevices(userId: string) {
    return this.prisma.device.findMany({
      where: { userId },
      select: {
        id: true,
        deviceUuid: true,
        name: true,
        platform: true,
        deviceModel: true,
        osVersion: true,
        appVersion: true,
        registrationLocation: true,
        registrationIp: true,
        pushToken: true,
        devicePublicKey: true,
        status: true,
        createdAt: true,
        lastSeenAt: true,
        revokedAt: true
      }
    });
  }

  async updatePushToken(userId: string, dto: UpdatePushTokenDto) {
    const device = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.deviceUuid }
    });
    if (!device) {
      throw new NotFoundException(`Device ${dto.deviceUuid} not found`);
    }
    if (device.userId !== userId) {
      throw new ForbiddenException('Device belongs to another user');
    }

    const endpoint = dto.endpoint || 'fcm';

    await this.prisma.device.update({
      where: { id: device.id },
      data: { pushToken: dto.pushToken }
    });

    await this.prisma.pushDevice.upsert({
      where: {
        deviceId_endpoint: {
          deviceId: device.id,
          endpoint
        }
      },
      update: {
        clientToken: dto.pushToken
      },
      create: {
        deviceId: device.id,
        clientToken: dto.pushToken,
        endpoint
      }
    });

    return { success: true, message: 'Push token updated successfully' };
  }

  async revokeDevice(userId: string, deviceId: string) {
    const device = await this.prisma.device.findUnique({
      where: { id: deviceId }
    });
    if (!device) {
      throw new NotFoundException('Device not found');
    }
    if (device.userId !== userId) {
      throw new ForbiddenException('Not authorized to revoke this device');
    }

    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.device.update({
        where: { id: deviceId },
        data: {
          status: 'REVOKED',
          revokedAt: now
        }
      }),
      this.prisma.session.deleteMany({
        where: { deviceId }
      }),
      this.prisma.securityEvent.create({
        data: {
          userId,
          deviceId,
          eventType: 'DEVICE_REVOKED',
          severity: 'HIGH',
          details: JSON.stringify({ revokedAt: now, deviceUuid: device.deviceUuid })
        }
      })
    ]);

    return { success: true, message: 'Device revoked' };
  }
}

