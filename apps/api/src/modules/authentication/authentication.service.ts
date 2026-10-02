import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Optional
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { GotifyService } from '../../infrastructure/gotify/gotify.service';
import { RedisService } from '../../infrastructure/redis/redis.service';
import {
  RegisterDto,
  LoginDto,
  SendOtpDto,
  VerifyOtpDto,
  Verify2FaDto,
  RegisterIdentityDto,
  RestoreIdentityDto,
  TransferResponseDto
} from './dto/auth.dto';

@Injectable()
export class AuthenticationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @Optional() private readonly gotifyService?: GotifyService,
    @Optional() private readonly redisService?: RedisService
  ) {}

  async sendOtp(dto: SendOtpDto) {
    const identifier = dto.identifier.trim();
    if (!identifier) {
      throw new BadRequestException('Identifier (phone or email) is required');
    }

    // Generate 6-digit OTP (123456 in dev, random in production)
    const isDev = this.configService.get<string>('NODE_ENV') !== 'production';
    const code = isDev ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();

    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 5);

    // Invalidate previous unverified OTPs for this identifier
    await this.prisma.otpCode.updateMany({
      where: { identifier, verified: false },
      data: { verified: true }
    });

    await this.prisma.otpCode.create({
      data: {
        identifier,
        code,
        type: dto.type || 'LOGIN',
        expiresAt,
        verified: false
      }
    });

    return {
      success: true,
      message: `OTP sent successfully to ${identifier}`,
      identifier,
      expiresInSeconds: 300,
      devCode: isDev ? code : undefined
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const identifier = dto.identifier.trim();
    const code = dto.code.trim();

    const otp = await this.prisma.otpCode.findFirst({
      where: {
        identifier,
        code,
        verified: false,
        expiresAt: { gt: new Date() }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (!otp) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { verified: true }
    });

    return {
      success: true,
      verified: true,
      identifier
    };
  }

  async register(dto: RegisterDto) {
    const username = dto.username.trim();
    const existingUsername = await this.prisma.user.findUnique({
      where: { username }
    });
    if (existingUsername) {
      throw new ConflictException('Username is already taken');
    }

    let email: string | undefined = dto.email?.trim();
    let phoneNumber: string | undefined = dto.phoneNumber?.trim();

    if (dto.identifier) {
      const idStr = dto.identifier.trim();
      if (idStr.includes('@')) {
        email = idStr;
      } else {
        phoneNumber = idStr;
      }
    }

    if (email) {
      const existingEmail = await this.prisma.user.findUnique({
        where: { email }
      });
      if (existingEmail) {
        throw new ConflictException('Email address is already registered');
      }
    }

    if (phoneNumber) {
      const existingPhone = await this.prisma.user.findUnique({
        where: { phoneNumber }
      });
      if (existingPhone) {
        throw new ConflictException('Phone number is already registered');
      }
    }

    // If OTP code is provided, verify it
    if (dto.otpCode && (email || phoneNumber)) {
      const ident = (email || phoneNumber)!;
      await this.verifyOtp({ identifier: ident, code: dto.otpCode });
    }

    const salt = await bcrypt.genSalt(10);
    const password = dto.password || 'SecureDefaultPass123!';
    const passwordHash = await bcrypt.hash(password, salt);
    const defaultPinHash = await bcrypt.hash('123456', salt);

    const user = await this.prisma.user.create({
      data: {
        username,
        email,
        phoneNumber,
        passwordHash,
        twoFactorEnabled: false,
        twoFactorPin: defaultPinHash,
        status: 'ACTIVE'
      }
    });

    // Upsert device by deviceUuid to support re-registration on same hardware
    let device = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.deviceUuid }
    });

    if (!device) {
      device = await this.prisma.device.create({
        data: {
          userId: user.id,
          deviceUuid: dto.deviceUuid,
          name: dto.deviceName || 'Primary Device',
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    } else {
      device = await this.prisma.device.update({
        where: { id: device.id },
        data: {
          userId: user.id,
          name: dto.deviceName || device.name,
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    }

    const tokens = await this.generateTokens(user.id, device.id);
    return {
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        phoneNumber: user.phoneNumber,
        twoFactorEnabled: user.twoFactorEnabled
      },
      device: { id: device.id, deviceUuid: device.deviceUuid },
      ...tokens
    };
  }

  async login(dto: LoginDto) {
    const identifier = dto.identifier.trim();

    // Find user by username, email, or phone number
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { username: identifier },
          { email: identifier },
          { phoneNumber: identifier }
        ]
      }
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status === 'SUSPENDED') {
      throw new ForbiddenException({
        statusCode: 403,
        error: 'ACCOUNT_SUSPENDED',
        message: 'Akun Anda telah ditangguhkan.',
        reason: user.suspendedReason || 'Pelanggaran ketentuan layanan'
      });
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Akun tidak aktif');
    }

    // Verify OTP or password
    if (dto.otpCode) {
      await this.verifyOtp({ identifier, code: dto.otpCode });
    } else if (dto.password) {
      const isMatch = await bcrypt.compare(dto.password, user.passwordHash);
      if (!isMatch) {
        throw new UnauthorizedException('Invalid credentials');
      }
    } else {
      throw new BadRequestException('Either password or OTP code must be provided');
    }

    // Check if 2FA (Two-Step Verification) is enabled
    if (user.twoFactorEnabled) {
      const secret = this.configService.get<string>('JWT_SECRET');
      const tempToken = this.jwtService.sign(
        { sub: user.id, is2FaPending: true, deviceUuid: dto.deviceUuid },
        { secret, expiresIn: '5m' }
      );

      return {
        requiresTwoFactor: true,
        tempToken,
        methods: ['PIN', 'BIOMETRIC'],
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          phoneNumber: user.phoneNumber
        }
      };
    }

    let device = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.deviceUuid }
    });

    if (!device) {
      device = await this.prisma.device.create({
        data: {
          userId: user.id,
          deviceUuid: dto.deviceUuid,
          name: dto.deviceName || 'Device',
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    } else {
      if (device.status === 'REVOKED' || device.status === 'CONTAINED' || device.status === 'DECOMMISSIONED') {
        throw new UnauthorizedException(`Device is ${device.status}`);
      }
      device = await this.prisma.device.update({
        where: { id: device.id },
        data: {
          userId: user.id,
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    }

    const tokens = await this.generateTokens(user.id, device.id);
    return {
      requiresTwoFactor: false,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        phoneNumber: user.phoneNumber,
        twoFactorEnabled: user.twoFactorEnabled
      },
      device: { id: device.id, deviceUuid: device.deviceUuid },
      ...tokens
    };
  }

  async verify2Fa(dto: Verify2FaDto) {
    const secret = this.configService.get<string>('JWT_SECRET');
    let payload: any;

    try {
      payload = this.jwtService.verify(dto.tempToken, { secret });
    } catch {
      throw new UnauthorizedException('2FA verification session expired or invalid');
    }

    if (!payload?.is2FaPending || !payload?.sub) {
      throw new UnauthorizedException('Invalid 2FA session token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub }
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (user.status === 'SUSPENDED') {
      throw new ForbiddenException({
        statusCode: 403,
        error: 'ACCOUNT_SUSPENDED',
        message: 'Akun Anda telah ditangguhkan.',
        reason: user.suspendedReason || 'Pelanggaran ketentuan layanan'
      });
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Akun tidak aktif');
    }

    // Check PIN: verify with bcrypt or plaintext fallback with auto-migration
    const storedPin = (user.twoFactorPin || '123456').trim();
    const inputPin = dto.pin.trim();
    let isPinMatch = false;

    if (storedPin.startsWith('$2a$') || storedPin.startsWith('$2b$')) {
      try {
        isPinMatch = await bcrypt.compare(inputPin, storedPin);
      } catch {
        isPinMatch = false;
      }
    } else {
      isPinMatch = (inputPin === storedPin);
      if (isPinMatch) {
        try {
          const salt = await bcrypt.genSalt(10);
          const hashedPin = await bcrypt.hash(inputPin, salt);
          await this.prisma.user.update({
            where: { id: user.id },
            data: { twoFactorPin: hashedPin }
          });
        } catch (_) {}
      }
    }

    if (!isPinMatch) {
      throw new UnauthorizedException('Invalid security PIN');
    }

    let device = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.deviceUuid }
    });

    if (!device) {
      device = await this.prisma.device.create({
        data: {
          userId: user.id,
          deviceUuid: dto.deviceUuid,
          name: dto.deviceName || 'Device',
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    } else {
      await this.prisma.device.update({
        where: { id: device.id },
        data: {
          lastSeenAt: new Date(),
          ...(device.status === 'INACTIVE' ? { status: 'ACTIVE' } : {})
        }
      });
    }

    const tokens = await this.generateTokens(user.id, device.id);
    return {
      requiresTwoFactor: false,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        phoneNumber: user.phoneNumber,
        twoFactorEnabled: user.twoFactorEnabled
      },
      device: { id: device.id, deviceUuid: device.deviceUuid },
      ...tokens
    };
  }

  async logout(userId: string, deviceId: string) {
    await this.prisma.$transaction([
      this.prisma.session.deleteMany({
        where: { userId, deviceId }
      }),
      this.prisma.device.updateMany({
        where: { id: deviceId, userId },
        data: { status: 'INACTIVE' }
      })
    ]);
    return { success: true };
  }

  async registerIdentity(dto: RegisterIdentityDto) {
    const username = dto.username.trim();
    const identityPublicKey = dto.identityPublicKey.trim();

    const existingUsername = await this.prisma.user.findUnique({
      where: { username }
    });
    if (existingUsername) {
      throw new ConflictException('Username is already taken');
    }

    const existingKey = await this.prisma.user.findUnique({
      where: { identityPublicKey }
    });
    if (existingKey) {
      throw new ConflictException('Identity public key is already registered');
    }

    let twoFactorPin: string | null = null;
    if (dto.pin && dto.pin.trim().length > 0) {
      const salt = await bcrypt.genSalt(10);
      twoFactorPin = await bcrypt.hash(dto.pin.trim(), salt);
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Create User Identity
      const user = await tx.user.create({
        data: {
          username,
          identityPublicKey,
          twoFactorPin,
          status: 'ACTIVE',
          twoFactorEnabled: false
        }
      });

      // 2. Create Device
      let device = await tx.device.findUnique({
        where: { deviceUuid: dto.deviceUuid }
      });

      if (!device) {
        device = await tx.device.create({
          data: {
            userId: user.id,
            deviceUuid: dto.deviceUuid,
            devicePublicKey: dto.devicePublicKey,
            name: dto.deviceName || 'Primary Device',
            platform: dto.platform || 'android',
            deviceModel: dto.deviceModel || null,
            osVersion: dto.osVersion || null,
            appVersion: dto.appVersion || '1.0.0',
            registrationLocation: dto.registrationLocation || null,
            registrationIp: dto.registrationIp || null,
            pushToken: dto.pushToken || null,
            attestationData: dto.attestationData,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      } else {
        device = await tx.device.update({
          where: { id: device.id },
          data: {
            userId: user.id,
            devicePublicKey: dto.devicePublicKey,
            name: dto.deviceName || device.name,
            platform: dto.platform || device.platform,
            deviceModel: dto.deviceModel || device.deviceModel,
            osVersion: dto.osVersion || device.osVersion,
            appVersion: dto.appVersion || device.appVersion,
            registrationLocation: dto.registrationLocation || device.registrationLocation,
            registrationIp: dto.registrationIp || device.registrationIp,
            pushToken: dto.pushToken || device.pushToken,
            attestationData: dto.attestationData || device.attestationData,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      }

      // 3. Register Identity Key
      await tx.deviceKey.create({
        data: {
          deviceId: device.id,
          identityKey: dto.devicePublicKey
        }
      });

      // 4. Save Signed Pre-Key
      if (dto.signedPreKey) {
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
      }

      // 5. Save One-Time Pre-Keys
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

      // 6. Save Push Device Token if provided
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

      // 7. Record Audit Event
      await tx.securityEvent.create({
        data: {
          userId: user.id,
          deviceId: device.id,
          eventType: 'IDENTITY_REGISTERED',
          severity: 'LOW',
          details: JSON.stringify({
            username: user.username,
            deviceUuid: device.deviceUuid,
            platform: dto.platform || 'android',
            deviceModel: device.deviceModel,
            registrationLocation: device.registrationLocation
          })
        }
      });

      const tokens = await this.generateTokens(user.id, device.id, tx);

      return {
        user: {
          id: user.id,
          username: user.username,
          identityPublicKey: user.identityPublicKey,
          status: user.status
        },
        device: {
          id: device.id,
          deviceUuid: device.deviceUuid,
          name: device.name,
          platform: device.platform,
          deviceModel: device.deviceModel,
          registrationLocation: device.registrationLocation,
          status: device.status
        },
        ...tokens
      };
    });
  }

  async restoreIdentity(dto: RestoreIdentityDto) {
    const raw = dto.identitySecret.trim();
    const identityPub = dto.identityPublicKey?.trim();
    const sha256Secret = crypto.createHash('sha256').update(raw).digest('hex');

    // Look for existing user by deterministic sha256, identityPublicKey, secret, or username
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { identityPublicKey: sha256Secret },
          ...(identityPub ? [{ identityPublicKey: identityPub }] : []),
          { identityPublicKey: raw },
          { username: raw }
        ]
      }
    });

    if (!user) {
      throw new NotFoundException('Kunci rahasia atau akun tidak ditemukan. Pastikan kunci pemulihan atau username sesuai.');
    }

    if (user.status === 'SUSPENDED') {
      throw new ForbiddenException({
        statusCode: 403,
        error: 'ACCOUNT_SUSPENDED',
        message: 'Akun Anda telah ditangguhkan.',
        reason: user.suspendedReason || 'Pelanggaran ketentuan layanan'
      });
    }

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException(`Akun tidak aktif (status: ${user.status})`);
    }

    // Verify security PIN if set on the account
    if (user.twoFactorPin) {
      if (!dto.pin || dto.pin.trim().length === 0) {
        throw new BadRequestException('PIN Keamanan 6-digit diperlukan untuk memulihkan akun');
      }
      let isPinMatch = false;
      const storedPin = user.twoFactorPin.trim();
      const trimmedPin = dto.pin.trim();

      if (storedPin.startsWith('$2a$') || storedPin.startsWith('$2b$')) {
        try {
          isPinMatch = await bcrypt.compare(trimmedPin, storedPin);
        } catch {
          isPinMatch = false;
        }
      } else {
        isPinMatch = (trimmedPin === storedPin);
        if (isPinMatch) {
          try {
            const salt = await bcrypt.genSalt(10);
            const hashedPin = await bcrypt.hash(trimmedPin, salt);
            await this.prisma.user.update({
              where: { id: user.id },
              data: { twoFactorPin: hashedPin }
            });
          } catch (_) {}
        }
      }

      if (!isPinMatch) {
        throw new UnauthorizedException('PIN Keamanan salah');
      }
    } else if (dto.pin && dto.pin.trim().length > 0) {
      // Legacy user who hadn't set twoFactorPin yet: save this PIN as their account PIN
      const salt = await bcrypt.genSalt(10);
      const hashedPin = await bcrypt.hash(dto.pin.trim(), salt);
      await this.prisma.user.update({
        where: { id: user.id },
        data: { twoFactorPin: hashedPin }
      });
    }

    // Check if user currently has an ACTIVE device other than the one requesting
    const activeDevice = await this.prisma.device.findFirst({
      where: {
        userId: user.id,
        status: 'ACTIVE',
        deviceUuid: { not: dto.deviceUuid }
      },
      include: { pushDevices: true },
      orderBy: { lastSeenAt: 'desc' }
    });

    // Skenario 1: Ada perangkat aktif dan BUKAN fallback darurat
    if (activeDevice && !dto.emergencyOverride) {
      const expiresAt = new Date(Date.now() + 3 * 60 * 1000); // 3 menit
      const transferRequest = await (this.prisma as any).deviceTransferRequest.create({
        data: {
          userId: user.id,
          targetDeviceUuid: dto.deviceUuid,
          targetDeviceName: dto.deviceName || 'Perangkat Baru',
          targetPlatform: dto.platform || 'android',
          targetPublicKey: dto.devicePublicKey,
          sourceDeviceId: activeDevice.id,
          status: 'PENDING',
          expiresAt
        }
      });

      const transferPayload = {
        type: 'DEVICE_TRANSFER_REQUESTED',
        requestId: transferRequest.id,
        deviceName: dto.deviceName || 'Perangkat Baru',
        platform: dto.platform || 'android',
        expiresAt: expiresAt.toISOString(),
        timestamp: Date.now()
      };

      if (this.redisService) {
        try {
          await this.redisService.publish(`user:${user.id}`, JSON.stringify(transferPayload));
        } catch (_) {}
      }

      if (this.gotifyService) {
        const tokens: string[] = [];
        if (activeDevice.pushToken) tokens.push(activeDevice.pushToken);
        if (activeDevice.pushDevices) {
          for (const pd of activeDevice.pushDevices) {
            if (pd.clientToken && !tokens.includes(pd.clientToken)) tokens.push(pd.clientToken);
          }
        }
        for (const t of tokens) {
          this.gotifyService.sendPushNotification({
            title: '⚠️ Permintaan Pemulihan Akun',
            message: `Perangkat ${dto.deviceName || 'baru'} mencoba memulihkan akun Anda. Buka aplikasi untuk menyetujui atau menolak.`,
            priority: 8,
            targetToken: t
          }).catch(() => {});
        }
      }

      return {
        requiresApproval: true,
        requestId: transferRequest.id,
        activeDeviceName: activeDevice.name || activeDevice.deviceModel || 'Perangkat Utama',
        expiresAt: expiresAt.toISOString(),
        message: `Permintaan persetujuan telah dikirimkan ke perangkat aktif (${activeDevice.name || activeDevice.deviceModel || 'HP Utama'}).`
      };
    }

    // Skenario 2: Tidak ada perangkat aktif ATAU user memilih Fallback Darurat
    if (activeDevice && dto.emergencyOverride) {
      const now = new Date();
      await this.prisma.device.update({
        where: { id: activeDevice.id },
        data: { status: 'INACTIVE', revokedAt: now }
      });
      await this.prisma.session.deleteMany({
        where: { deviceId: activeDevice.id }
      });

      if (this.redisService) {
        try {
          await this.redisService.publish(`user:${user.id}`, JSON.stringify({
            type: 'DEVICE_REVOKED',
            reason: 'Akun dipulihkan di perangkat baru via otentikasi darurat.',
            timestamp: Date.now()
          }));
        } catch (_) {}
      }

      await this.prisma.securityEvent.create({
        data: {
          userId: user.id,
          deviceId: activeDevice.id,
          eventType: 'EMERGENCY_RESTORE_OVERRIDE',
          severity: 'HIGH',
          details: JSON.stringify({
            displacedDeviceId: activeDevice.id,
            targetDeviceUuid: dto.deviceUuid,
            deviceName: dto.deviceName
          })
        }
      });
    }

    // Upsert or register the device for this user
    let device = await this.prisma.device.findUnique({
      where: { deviceUuid: dto.deviceUuid }
    });

    if (!device) {
      device = await this.prisma.device.create({
        data: {
          userId: user.id,
          deviceUuid: dto.deviceUuid,
          name: dto.deviceName || 'Restored Device',
          platform: dto.platform || 'android',
          devicePublicKey: dto.devicePublicKey || `dev_pub_${Date.now()}`,
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    } else {
      device = await this.prisma.device.update({
        where: { id: device.id },
        data: {
          userId: user.id,
          name: dto.deviceName || device.name,
          platform: dto.platform || device.platform,
          devicePublicKey: dto.devicePublicKey || device.devicePublicKey,
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    }

    const tokens = await this.generateTokens(user.id, device.id);

    return {
      requiresApproval: false,
      user: {
        id: user.id,
        username: user.username,
        identityPublicKey: user.identityPublicKey,
        status: user.status
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

  async getTransferStatus(requestId: string) {
    const request = await (this.prisma as any).deviceTransferRequest.findUnique({
      where: { id: requestId },
      include: {
        user: true,
        sourceDevice: true
      }
    });

    if (!request) {
      throw new NotFoundException('Tiket permintaan pemindahan tidak ditemukan');
    }

    if (request.status === 'PENDING' && new Date() > request.expiresAt) {
      await (this.prisma as any).deviceTransferRequest.update({
        where: { id: requestId },
        data: { status: 'EXPIRED' }
      });
      return {
        status: 'EXPIRED',
        message: 'Waktu persetujuan dari perangkat utama telah kedaluwarsa.'
      };
    }

    if (request.status === 'PENDING') {
      return {
        status: 'PENDING',
        expiresAt: request.expiresAt,
        activeDeviceName: request.sourceDevice?.name || request.sourceDevice?.deviceModel || 'Perangkat Utama'
      };
    }

    if (request.status === 'REJECTED') {
      return {
        status: 'REJECTED',
        message: 'Permintaan pemindahan akun ditolak oleh pemilik perangkat utama.'
      };
    }

    if (request.status === 'APPROVED') {
      let targetDevice = await this.prisma.device.findUnique({
        where: { deviceUuid: request.targetDeviceUuid }
      });

      if (!targetDevice) {
        targetDevice = await this.prisma.device.create({
          data: {
            userId: request.userId,
            deviceUuid: request.targetDeviceUuid,
            name: request.targetDeviceName || 'Restored Device',
            platform: request.targetPlatform || 'android',
            devicePublicKey: request.targetPublicKey || `dev_pub_${Date.now()}`,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      } else {
        targetDevice = await this.prisma.device.update({
          where: { id: targetDevice.id },
          data: {
            userId: request.userId,
            status: 'ACTIVE',
            lastSeenAt: new Date()
          }
        });
      }

      const tokens = await this.generateTokens(request.userId, targetDevice.id);

      return {
        status: 'APPROVED',
        user: {
          id: request.user.id,
          username: request.user.username,
          identityPublicKey: request.user.identityPublicKey,
          status: request.user.status
        },
        device: {
          id: targetDevice.id,
          deviceUuid: targetDevice.deviceUuid,
          name: targetDevice.name,
          status: targetDevice.status
        },
        ...tokens
      };
    }

    return {
      status: request.status
    };
  }

  async respondToTransfer(userId: string, currentDeviceId: string, dto: TransferResponseDto) {
    const request = await (this.prisma as any).deviceTransferRequest.findUnique({
      where: { id: dto.requestId }
    });

    if (!request || request.userId !== userId) {
      throw new NotFoundException('Permintaan pemindahan tidak ditemukan');
    }

    if (request.status !== 'PENDING') {
      throw new BadRequestException(`Permintaan sudah tidak aktif (Status: ${request.status})`);
    }

    if (new Date() > request.expiresAt) {
      await (this.prisma as any).deviceTransferRequest.update({
        where: { id: dto.requestId },
        data: { status: 'EXPIRED' }
      });
      throw new BadRequestException('Permintaan pemindahan telah kedaluwarsa');
    }

    if (dto.action === 'APPROVE') {
      const now = new Date();

      await (this.prisma as any).deviceTransferRequest.update({
        where: { id: dto.requestId },
        data: {
          status: 'APPROVED',
          approvedAt: now
        }
      });

      if (currentDeviceId) {
        await this.prisma.device.update({
          where: { id: currentDeviceId },
          data: {
            status: 'INACTIVE',
            revokedAt: now
          }
        });
        await this.prisma.session.deleteMany({
          where: { deviceId: currentDeviceId }
        });
      }

      let targetDevice = await this.prisma.device.findUnique({
        where: { deviceUuid: request.targetDeviceUuid }
      });

      if (!targetDevice) {
        await this.prisma.device.create({
          data: {
            userId,
            deviceUuid: request.targetDeviceUuid,
            name: request.targetDeviceName || 'Restored Device',
            platform: request.targetPlatform || 'android',
            devicePublicKey: request.targetPublicKey || `dev_pub_${Date.now()}`,
            status: 'ACTIVE',
            lastSeenAt: now
          }
        });
      } else {
        await this.prisma.device.update({
          where: { id: targetDevice.id },
          data: {
            userId,
            status: 'ACTIVE',
            lastSeenAt: now
          }
        });
      }

      await this.prisma.securityEvent.create({
        data: {
          userId,
          deviceId: currentDeviceId,
          eventType: 'DEVICE_TRANSFER_APPROVED',
          severity: 'MEDIUM',
          details: JSON.stringify({
            requestId: dto.requestId,
            displacedDeviceId: currentDeviceId,
            targetDeviceUuid: request.targetDeviceUuid
          })
        }
      });

      if (this.redisService) {
        try {
          await this.redisService.publish(`user:${userId}`, JSON.stringify({
            type: 'DEVICE_REVOKED',
            reason: 'Akun berhasil dipindahkan ke perangkat baru.',
            timestamp: Date.now()
          }));
          await this.redisService.publish(`transfer:${dto.requestId}`, JSON.stringify({
            status: 'APPROVED',
            timestamp: Date.now()
          }));
        } catch (_) {}
      }

      return {
        success: true,
        status: 'APPROVED',
        message: 'Pemindahan akun berhasil disetujui. Sesi perangkat ini dinonaktifkan.'
      };
    } else {
      const now = new Date();
      await (this.prisma as any).deviceTransferRequest.update({
        where: { id: dto.requestId },
        data: {
          status: 'REJECTED',
          rejectedAt: now
        }
      });

      await this.prisma.securityEvent.create({
        data: {
          userId,
          deviceId: currentDeviceId,
          eventType: 'TRANSFER_REJECTED_POTENTIAL_BREACH',
          severity: 'HIGH',
          details: JSON.stringify({
            requestId: dto.requestId,
            targetDeviceUuid: request.targetDeviceUuid,
            targetDeviceName: request.targetDeviceName
          })
        }
      });

      if (this.redisService) {
        try {
          await this.redisService.publish(`transfer:${dto.requestId}`, JSON.stringify({
            status: 'REJECTED',
            timestamp: Date.now()
          }));
        } catch (_) {}
      }

      return {
        success: true,
        status: 'REJECTED',
        message: 'Permintaan ditolak. Amankan akun Anda dengan memperbarui PIN Keamanan atau Kunci Cadangan.'
      };
    }
  }

  async getPendingTransferForUser(userId: string, deviceId?: string) {
    if (deviceId) {
      const dev = await this.prisma.device.findUnique({
        where: { id: deviceId },
        select: { status: true }
      });
      if (dev && (dev.status === 'REVOKED' || dev.status === 'INACTIVE')) {
        return {
          isRevoked: true,
          hasPendingTransfer: false,
          reason: 'Perangkat ini telah dinonaktifkan karena akun dipindahkan ke perangkat lain.'
        };
      }
    }

    const pending = await (this.prisma as any).deviceTransferRequest.findFirst({
      where: {
        userId,
        status: 'PENDING',
        expiresAt: { gt: new Date() }
      },
      orderBy: { createdAt: 'desc' }
    });

    if (pending) {
      return {
        isRevoked: false,
        hasPendingTransfer: true,
        request: {
          id: pending.id,
          targetDeviceName: pending.targetDeviceName,
          targetPlatform: pending.targetPlatform,
          expiresAt: pending.expiresAt
        }
      };
    }

    return {
      isRevoked: false,
      hasPendingTransfer: false
    };
  }

  async getIdentityMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        devices: {
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
            status: true,
            createdAt: true,
            lastSeenAt: true,
            revokedAt: true
          }
        }
      }
    });

    if (!user) {
      throw new NotFoundException('User identity not found');
    }

    return {
      id: user.id,
      username: user.username,
      identityPublicKey: user.identityPublicKey,
      status: user.status,
      devices: user.devices
    };
  }

  async generateTokens(userId: string, deviceId: string, tx?: any) {
    const prismaClient = tx || this.prisma;
    const secret = this.configService.get<string>('JWT_SECRET');
    const expiresIn = this.configService.get<string>('JWT_EXPIRES_IN') || '7d';

    // ── Single-Device Policy ──────────────────────────────────────────────────
    // Find all existing sessions belonging to OTHER devices for this user
    const oldSessions = await prismaClient.session.findMany({
      where: { userId, NOT: { deviceId } },
      select: { deviceId: true }
    });
    const oldDeviceIds: string[] = [...new Set<string>(oldSessions.map((s: any) => s.deviceId))];

    if (oldDeviceIds.length > 0) {
      // 1. Invalidate all sessions on other devices
      await prismaClient.session.deleteMany({
        where: { userId, NOT: { deviceId } }
      });

      // 2. Fetch push tokens BEFORE marking INACTIVE (for notifications)
      const displacedDevices = await prismaClient.device.findMany({
        where: { id: { in: oldDeviceIds }, userId },
        select: { id: true, pushToken: true, deviceUuid: true }
      });

      // 3. Mark displaced devices as INACTIVE (soft-kick; allows graceful re-login)
      await prismaClient.device.updateMany({
        where: { id: { in: oldDeviceIds }, userId },
        data: { status: 'INACTIVE' }
      });

      // 4. Audit trail for each displaced device
      for (const d of displacedDevices) {
        await prismaClient.securityEvent.create({
          data: {
            userId,
            deviceId: d.id,
            eventType: 'DEVICE_DISPLACED',
            severity: 'MEDIUM',
            details: JSON.stringify({
              newDeviceId: deviceId,
              reason: 'single_device_policy',
              displacedDeviceUuid: d.deviceUuid
            })
          }
        });
      }

      // 5. Send push notification to each displaced device (best-effort)
      if (this.gotifyService) {
        for (const d of displacedDevices) {
          if (d.pushToken) {
            try {
              await this.gotifyService.sendPushNotification({
                targetToken: d.pushToken,
                title: 'Sesi Berakhir',
                message: 'Akun kamu baru saja masuk di perangkat lain. Kamu telah dikeluarkan secara otomatis.',
                priority: 9
              });
            } catch (_) { /* non-blocking */ }
          }
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    const payload = { sub: userId, deviceId };
    const accessToken = this.jwtService.sign(payload, { secret, expiresIn });

    // Store session record for the NEW device
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await prismaClient.session.create({
      data: {
        userId,
        deviceId,
        tokenHash: accessToken.slice(-32), // indexed snippet for fast session validation
        expiresAt
      }
    });

    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn
    };
  }

  /**
   * Called by the mobile app on every startup to ensure the device record
   * is up-to-date and a fresh JWT is issued. Accepts the current valid JWT
   * (already verified by JwtAuthGuard) and a deviceUuid to upsert.
   */
  async refreshDevice(userId: string, deviceUuid: string, deviceName?: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User not found or not active');
    }

    // Upsert device by deviceUuid
    let device = await this.prisma.device.findUnique({ where: { deviceUuid } });
    if (!device) {
      device = await this.prisma.device.create({
        data: {
          userId,
          deviceUuid,
          name: deviceName || 'Mobile Device',
          status: 'ACTIVE',
          lastSeenAt: new Date()
        }
      });
    } else {
      // Re-activate device and bind to the current active user
      const canReactivate = device.status === 'ACTIVE' || device.status === 'PENDING' || device.status === 'MIGRATING';
      device = await this.prisma.device.update({
        where: { id: device.id },
        data: {
          userId,
          lastSeenAt: new Date(),
          ...(canReactivate ? { status: 'ACTIVE' } : {})
        }
      });
    }

    if (device.status === 'REVOKED' || device.status === 'CONTAINED' || device.status === 'DECOMMISSIONED') {
      throw new UnauthorizedException('Device has been permanently revoked');
    }

    const tokens = await this.generateTokens(userId, device.id);
    return {
      device: { id: device.id, deviceUuid: device.deviceUuid },
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        phoneNumber: user.phoneNumber,
        twoFactorEnabled: user.twoFactorEnabled
      },
      ...tokens
    };
  }
}

