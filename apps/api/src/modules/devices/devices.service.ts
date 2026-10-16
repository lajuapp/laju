import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  UnauthorizedException,
  BadRequestException,
  Logger,
  Optional
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import { AuthenticationService } from '../authentication/authentication.service';
import {
  RegisterDeviceDto,
  DeviceChallengeRequestDto,
  DeviceVerifyChallengeDto,
  UpdatePushTokenDto
} from './dto/devices.dto';

import { GotifyService } from '../../infrastructure/gotify/gotify.service';

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
    private readonly authService: AuthenticationService,
    @Optional() private readonly gotifyService?: GotifyService
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

    // Check if device is registered
    let isRegistered = false;
    let username: string | undefined;
    if (dto?.deviceUuid) {
      try {
        const dev = await this.prisma.device.findUnique({
          where: { deviceUuid: dto.deviceUuid },
          include: { user: { select: { username: true } } }
        });
        if (dev && (dev.status === 'ACTIVE' || dev.status === 'INACTIVE')) {
          isRegistered = true;
          username = dev.user.username;
        }
      } catch (_) {}
    }

    return {
      challenge: nonce,
      expiresInSeconds: ttlSeconds,
      expiresAt,
      isRegistered,
      username
    };
  }

  /**
   * Cryptographically verify signature over challenge and issue session tokens.
   */
  async verifyChallenge(dto: DeviceVerifyChallengeDto) {
    const { deviceUuid, challenge, signature, pin, newDevicePublicKey } = dto;

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

    if (device.status === 'REVOKED' || device.status === 'CONTAINED' || device.status === 'DECOMMISSIONED') {
      throw new UnauthorizedException(`Device is permanently ${device.status}`);
    }
    // NOTE: INACTIVE status is allowed — the device was displaced by single-device policy
    // or session was disconnected from backoffice / logged out, and user is now re-authenticating with PIN.

    if (device.user.status !== 'ACTIVE') {
      throw new UnauthorizedException(`User account is ${device.user.status}`);
    }

    let mechanism = 'CHALLENGE_RESPONSE';

    if (pin) {
      // Authenticate via PIN verification for re-attestation
      if (device.user.twoFactorPin) {
        let isPinMatch = false;
        const storedPin = device.user.twoFactorPin.trim();
        const trimmedPin = pin.trim();

        if (storedPin.startsWith('$2a$') || storedPin.startsWith('$2b$')) {
          try {
            isPinMatch = await bcrypt.compare(trimmedPin, storedPin);
          } catch {
            isPinMatch = false;
          }
        } else {
          // Plaintext fallback with auto-migration to bcrypt
          isPinMatch = (trimmedPin === storedPin);
          if (isPinMatch) {
            try {
              const salt = await bcrypt.genSalt(10);
              const hashedPin = await bcrypt.hash(trimmedPin, salt);
              await this.prisma.user.update({
                where: { id: device.user.id },
                data: { twoFactorPin: hashedPin }
              });
            } catch (_) {}
          }
        }

        if (!isPinMatch) {
          await this.prisma.securityEvent.create({
            data: {
              userId: device.userId,
              deviceId: device.id,
              eventType: 'DEVICE_PIN_VERIFY_FAILED',
              severity: 'HIGH',
              details: JSON.stringify({ deviceUuid, reason: 'Invalid PIN provided for device re-attestation' })
            }
          });
          throw new UnauthorizedException('PIN Keamanan salah');
        }
        mechanism = 'DEVICE_PIN_REATTEST';
      } else {
        // Legacy user without PIN set yet: set the PIN for this user
        const salt = await bcrypt.genSalt(10);
        const hashedPin = await bcrypt.hash(pin, salt);
        await this.prisma.user.update({
          where: { id: device.user.id },
          data: { twoFactorPin: hashedPin }
        });
        mechanism = 'DEVICE_PIN_INIT';
      }

      // If a new device public key was supplied during re-attestation, update it
      if (newDevicePublicKey) {
        await this.prisma.device.update({
          where: { id: device.id },
          data: { devicePublicKey: newDevicePublicKey }
        });
      }
    } else {
      // If device is INACTIVE (session disconnected or logged out), re-attestation requires PIN
      if (device.status === 'INACTIVE') {
        throw new UnauthorizedException('PIN_REATTEST_REQUIRED');
      }

      // Cryptographic signature check
      if (!signature) {
        throw new BadRequestException('Signature atau PIN diperlukan untuk verifikasi perangkat');
      }
      const publicKeyStr = device.devicePublicKey || device.deviceKeys[0]?.identityKey;
      if (!publicKeyStr) {
        throw new BadRequestException('No registered public key found for this device');
      }

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
    }

    // 5. Update device last seen and re-activate if displaced (INACTIVE)
    await this.prisma.device.update({
      where: { id: device.id },
      data: {
        lastSeenAt: new Date(),
        ...(device.status === 'INACTIVE' ? { status: 'ACTIVE' } : {})
      }
    });

    // 6. Record audit event
    await this.prisma.securityEvent.create({
      data: {
        userId: device.userId,
        deviceId: device.id,
        eventType: 'DEVICE_AUTHENTICATED',
        severity: 'LOW',
        details: JSON.stringify({ deviceUuid, mechanism })
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

  async testPushNotification(userId: string) {
    const devices = await this.prisma.device.findMany({
      where: { userId, status: 'ACTIVE' },
      include: { pushDevices: true }
    });

    let sentCount = 0;
    for (const device of devices) {
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
        await this.gotifyService.sendPushNotification({
          title: 'LAJU Push Test',
          message: 'Notifikasi uji coba berhasil dikirim (Global Wakeup)',
          priority: 6
        });
        sentCount++;
      } else {
        for (const token of tokens) {
          await this.gotifyService.sendPushNotification({
            targetToken: token,
            title: 'LAJU Push Test',
            message: 'Notifikasi uji coba berhasil diterima pada perangkat ini (Killed-State Active)',
            priority: 6
          });
          sentCount++;
        }
      }
    }

    return {
      success: true,
      sentCount,
      message: `Uji coba push notification dikirim ke ${sentCount} target token.`
    };
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

  getRedisSubscriber() {
    return this.redisService.getSubscriber();
  }

  getRedisService() {
    return this.redisService;
  }

  async getGotifyConfig() {
    return {
      gotifyUrl: process.env.GOTIFY_URL || 'http://gotify:80',
      clientToken: process.env.GOTIFY_CLIENT_TOKEN || ''
    };
  }

  /**
   * Retrieves pending push events (active ringing calls <60s, missed calls, and unread messages)
   * that occurred while the device's background push stream was temporarily asleep or disconnected.
   */
  async getPendingPushEvents(userId: string, sinceMs?: number): Promise<any[]> {
    const events: any[] = [];
    const now = Date.now();
    const ringingCutoff = new Date(now - 60 * 1000);
    const maxLookbackMs = now - 7 * 24 * 3600 * 1000;
    const defaultLookbackMs = now - 30 * 60 * 1000;
    const effectiveSinceMs =
      sinceMs && !Number.isNaN(sinceMs) && sinceMs > 0
        ? Math.max(sinceMs, maxLookbackMs)
        : defaultLookbackMs;
    const sinceDate = new Date(effectiveSinceMs);

    try {
      // 1. Auto-expire stale unanswered calls older than 60s so they are caught as missed calls below
      await this.prisma.call.updateMany({
        where: {
          state: 'INITIATED',
          startedAt: { lt: ringingCutoff },
          participants: {
            some: { userId, state: 'RINGING' }
          }
        },
        data: { state: 'ENDED', endedAt: new Date() }
      });

      // 2. Check for an active ringing call (<60s old)
      const ringingParticipant = await this.prisma.callParticipant.findFirst({
        where: {
          userId,
          state: 'RINGING',
          call: {
            state: 'INITIATED',
            startedAt: { gte: ringingCutoff }
          }
        },
        include: { call: true },
        orderBy: { joinedAt: 'desc' }
      });

      if (ringingParticipant && ringingParticipant.call.initiatorId !== userId) {
        const caller = await this.prisma.user.findUnique({
          where: { id: ringingParticipant.call.initiatorId },
          select: { username: true }
        });
        let isVideo = false;
        let isGroup = false;
        let groupName: string | undefined;
        let conversationId: string | undefined;
        try {
          const metaStr = await this.redisService.get(`call:${ringingParticipant.callId}:meta`);
          if (metaStr) {
            const meta = JSON.parse(metaStr);
            isVideo = !!meta.isVideo;
            isGroup = !!meta.isGroup;
            groupName = meta.groupName;
            conversationId = meta.conversationId;
          }
        } catch (_) {}

        events.push({
          type: 'CALL_INCOMING',
          callId: ringingParticipant.callId,
          conversationId: conversationId || '',
          initiatorId: ringingParticipant.call.initiatorId,
          initiatorName: caller?.username || 'Kontak',
          isVideo,
          isGroup,
          groupName,
          timestamp: ringingParticipant.call.startedAt.getTime()
        });
      }

      // 3. Check for missed calls that occurred while disconnected (since sinceDate)
      const missedParticipants = await this.prisma.callParticipant.findMany({
        where: {
          userId,
          state: 'RINGING',
          joinedAt: { gte: sinceDate },
          call: {
            initiatorId: { not: userId },
            state: 'ENDED',
            startedAt: { gte: sinceDate }
          }
        },
        include: { call: true },
        orderBy: { joinedAt: 'asc' },
        take: 5
      });

      for (const mp of missedParticipants) {
        const caller = await this.prisma.user.findUnique({
          where: { id: mp.call.initiatorId },
          select: { username: true }
        });
        let isVideo = false;
        let conversationId = '';
        try {
          const metaStr = await this.redisService.get(`call:${mp.callId}:meta`);
          if (metaStr) {
            const meta = JSON.parse(metaStr);
            isVideo = !!meta.isVideo;
            conversationId = meta.conversationId || '';
          }
        } catch (_) {}

        events.push({
          type: 'CALL_MISSED',
          callId: mp.callId,
          conversationId,
          initiatorId: mp.call.initiatorId,
          initiatorName: caller?.username || 'Kontak',
          isVideo,
          timestamp: mp.call.startedAt.getTime()
        });
      }

      // 4. Check for unread incoming messages (state = 'SENT') since sinceDate
      const unreadMessages = await this.prisma.message.findMany({
        where: {
          senderUserId: { not: userId },
          state: 'SENT',
          nonce: { not: 'call-log' },
          createdAt: { gte: sinceDate },
          conversation: {
            members: {
              some: { userId, leftAt: null }
            }
          }
        },
        include: {
          senderUser: {
            select: { id: true, username: true }
          }
        },
        orderBy: { createdAt: 'asc' },
        take: 10
      });

      for (const msg of unreadMessages) {
        const senderName = msg.senderUser?.username || 'Pesan Baru';
        const preview =
          msg.messageType === 'TEXT'
            ? 'Pesan baru terenkripsi'
            : `Mengirim ${msg.messageType.toLowerCase()}`;
        events.push({
          type: 'NEW_MESSAGE',
          conversationId: msg.conversationId,
          senderName,
          preview,
          messageId: msg.id,
          timestamp: msg.createdAt.getTime(),
          message: {
            id: msg.id,
            conversationId: msg.conversationId,
            senderUserId: msg.senderUserId,
            senderDeviceId: msg.senderDeviceId,
            messageType: msg.messageType,
            state: msg.state,
            createdAt: msg.createdAt,
            sequence: msg.sequence
          }
        });
      }
    } catch (err: any) {
      this.logger.warn(`getPendingPushEvents error for user ${userId}: ${err.message}`);
    }

    return events;
  }
}

