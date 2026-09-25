import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import * as crypto from 'crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  RegisterDto,
  LoginDto,
  SendOtpDto,
  VerifyOtpDto,
  Verify2FaDto,
  RegisterIdentityDto,
  RestoreIdentityDto
} from './dto/auth.dto';

@Injectable()
export class AuthenticationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService
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

    const user = await this.prisma.user.create({
      data: {
        username,
        email,
        phoneNumber,
        passwordHash,
        twoFactorEnabled: false,
        twoFactorPin: '123456',
        status: 'ACTIVE'
      }
    });

    // Create device
    const device = await this.prisma.device.create({
      data: {
        userId: user.id,
        deviceUuid: dto.deviceUuid,
        name: dto.deviceName || 'Primary Device',
        status: 'ACTIVE',
        lastSeenAt: new Date()
      }
    });

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

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Invalid credentials or account inactive');
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
      if (device.status !== 'ACTIVE') {
        throw new UnauthorizedException(`Device is ${device.status}`);
      }
      await this.prisma.device.update({
        where: { id: device.id },
        data: { lastSeenAt: new Date() }
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

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User not found or suspended');
    }

    // Check PIN: compare with user's stored PIN or default 123456
    const expectedPin = user.twoFactorPin || '123456';
    if (dto.pin !== expectedPin) {
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
        data: { lastSeenAt: new Date() }
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
    await this.prisma.session.deleteMany({
      where: { userId, deviceId }
    });
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

    if (user.status !== 'ACTIVE') {
      throw new UnauthorizedException(`Akun tidak aktif (status: ${user.status})`);
    }

    // Verify security PIN if set on the account
    if (user.twoFactorPin) {
      if (!dto.pin || dto.pin.trim().length === 0) {
        throw new BadRequestException('PIN Keamanan 6-digit diperlukan untuk memulihkan akun');
      }
      const isPinMatch = await bcrypt.compare(dto.pin.trim(), user.twoFactorPin);
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

    const payload = { sub: userId, deviceId };
    const accessToken = this.jwtService.sign(payload, { secret, expiresIn });

    // Store session record
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
}

